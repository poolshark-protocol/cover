// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import './math/DyDxMath.sol';
import './TwapOracle.sol';
import '../interfaces/IRangePool.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './Deltas.sol';
import './TickMap.sol';
import './EpochMap.sol';

library Epochs {
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    error InfiniteTickLoop0(int24);
    error InfiniteTickLoop1(int24);

    function syncLatest(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks0,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks1,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.PoolState memory pool0,
        ICoverPoolStructs.PoolState memory pool1,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants
    ) external returns (
        ICoverPoolStructs.GlobalState memory,
        ICoverPoolStructs.PoolState memory,
        ICoverPoolStructs.PoolState memory
    )
    {
        int24 newLatestTick;
        {
            bool earlyReturn;
            (newLatestTick, earlyReturn) = _syncTick(state, constants);
            if (earlyReturn) {
                return (state, pool0, pool1);
            }
            // else we have a TWAP update
        }

        // increase epoch counter
        state.accumEpoch += 1;

        // setup cache
        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            nextTickToCross0: state.latestTick, // above
            nextTickToCross1: state.latestTick, // below
            nextTickToAccum0: TickMap.previous(tickMap, state.latestTick), // below
            nextTickToAccum1: TickMap.next(tickMap, state.latestTick),     // above
            stopTick0: (newLatestTick > state.latestTick) // where we do stop for pool0 sync
                ? state.latestTick - state.tickSpread
                : newLatestTick, 
            stopTick1: (newLatestTick > state.latestTick) // where we do stop for pool1 sync
                ? newLatestTick
                : state.latestTick + state.tickSpread,
            deltas0: ICoverPoolStructs.Deltas(0, 0, 0, 0), // deltas for pool0
            deltas1: ICoverPoolStructs.Deltas(0, 0, 0, 0)  // deltas for pool1
        });

        while (true) {
            // get values from current auction
            (cache, pool0) = _rollover(state, cache, pool0, true);
            if (cache.nextTickToAccum0 > cache.stopTick0 
                 && ticks0[cache.nextTickToAccum0].amountInDeltaMaxMinus > 0) {
                EpochMap.set(tickMap, cache.nextTickToAccum0, state.accumEpoch);
            }
            // accumulate to next tick
            ICoverPoolStructs.AccumulateOutputs memory outputs;
            outputs = _accumulate(
                ticks0[cache.nextTickToCross0],
                ticks0[cache.nextTickToAccum0],
                cache.deltas0,
                newLatestTick > state.latestTick
                    ? cache.nextTickToAccum0 == cache.stopTick0
                    : cache.nextTickToAccum0 >= cache.stopTick0
            );
            /// @dev - deltas in cache updated after _accumulate
            cache.deltas0 = outputs.deltas;
            ticks0[cache.nextTickToCross0] = outputs.crossTick;
            ticks0[cache.nextTickToAccum0] = outputs.accumTick;
            
            // keep looping until accumulation reaches stopTick0 
            if (cache.nextTickToAccum0 >= cache.stopTick0) {
                (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                    tickMap,
                    ticks0[cache.nextTickToAccum0].liquidityDelta,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true
                );
            } else break;
        }
        // pool0 checkpoint
        {
            // create stopTick0 if necessary
            if (cache.nextTickToAccum0 != cache.stopTick0) {
                TickMap.set(tickMap, cache.stopTick0);
            }
            ICoverPoolStructs.Tick memory stopTick0 = ticks0[cache.stopTick0];
            // checkpoint at stopTick0
            (stopTick0) = _stash(
                stopTick0,
                cache,
                pool0.liquidity,
                true
            );
            EpochMap.set(tickMap, cache.stopTick0, state.accumEpoch);
            ticks0[cache.stopTick0] = stopTick0;
        }

        while (true) {
            // rollover deltas pool1
            (cache, pool1) = _rollover(state, cache, pool1, false);
            // accumulate deltas pool1
            if (cache.nextTickToAccum1 < cache.stopTick1 
                 && ticks1[cache.nextTickToAccum1].amountInDeltaMaxMinus > 0) {
                EpochMap.set(tickMap, cache.nextTickToAccum1, state.accumEpoch);
            }
            {
                ICoverPoolStructs.AccumulateOutputs memory outputs;
                outputs = _accumulate(
                    ticks1[cache.nextTickToCross1],
                    ticks1[cache.nextTickToAccum1],
                    cache.deltas1,
                    newLatestTick > state.latestTick
                        ? cache.nextTickToAccum1 <= cache.stopTick1
                        : cache.nextTickToAccum1 == cache.stopTick1
                );
                /// @dev - deltas in cache updated after _accumulate
                cache.deltas1 = outputs.deltas;
                ticks1[cache.nextTickToCross1] = outputs.crossTick;
                ticks1[cache.nextTickToAccum1] = outputs.accumTick;
            }
            // keep looping until accumulation reaches stopTick1 
            if (cache.nextTickToAccum1 <= cache.stopTick1) {
                (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                    tickMap,
                    ticks1[cache.nextTickToAccum1].liquidityDelta,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false
                );
            } else break;
        }
        // pool1 checkpoint
        {
            // create stopTick1 if necessary
            if (cache.nextTickToAccum1 != cache.stopTick1) {
                TickMap.set(tickMap, cache.stopTick1);
            }
            ICoverPoolStructs.Tick memory stopTick1 = ticks1[cache.stopTick1];
            // update deltas on stopTick
            (stopTick1) = _stash(
                stopTick1,
                cache,
                pool1.liquidity,
                false
            );
            ticks1[cache.stopTick1] = stopTick1;
            EpochMap.set(tickMap, cache.stopTick1, state.accumEpoch);
        }
        // update ending pool price for fully filled auction
        state.latestPrice = TickMath.getSqrtRatioAtTick(newLatestTick);
        
        // set pool price and liquidity
        if (newLatestTick > state.latestTick) {
            pool0.liquidity = 0;
            pool0.price = state.latestPrice;
            pool1.price = TickMath.getSqrtRatioAtTick(newLatestTick + state.tickSpread);
        } else {
            pool1.liquidity = 0;
            pool0.price = TickMath.getSqrtRatioAtTick(newLatestTick - state.tickSpread);
            pool1.price = state.latestPrice;
        }
        
        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.timestamp) - state.genesisTime;
        state.latestTick = newLatestTick;
    
        return (state, pool0, pool1);
    }

    function _syncTick(
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants
    ) internal view returns(
        int24 newLatestTick,
        bool
    ) {
        // update last block checked
        if(state.lastTime == uint32(block.timestamp) - state.genesisTime) {
            return (0, true);
        }
        state.lastTime = uint32(block.timestamp) - state.genesisTime;
        // check auctions elapsed
        int32 auctionsElapsed = int32((uint32(block.timestamp) - state.genesisTime - state.auctionStart) / state.auctionLength);

        if (auctionsElapsed == 0) {
            return (0, true);
        }
        newLatestTick = TwapOracle.calculateAverageTick(state.inputPool, state.twapLength);

        /// @dev - shift up/down one quartile to put pool ahead of TWAP
        if (newLatestTick > state.latestTick)
             newLatestTick += state.tickSpread / 4;
        else newLatestTick -= state.tickSpread / 4;
        newLatestTick = newLatestTick / state.tickSpread * state.tickSpread; // even multiple of tickSpread

        if (newLatestTick == state.latestTick) {
            return (0, true);
        }

        // rate-limiting tick move
        int24 maxLatestTickMove = int24(state.tickSpread * auctionsElapsed);

        /// @dev - latestTick can only move based on auctionsElapsed 
        if (newLatestTick > state.latestTick) {
            if (newLatestTick - state.latestTick > maxLatestTickMove)
                newLatestTick = state.latestTick + maxLatestTickMove;
        } else {
            if (state.latestTick - newLatestTick > maxLatestTickMove)
                newLatestTick = state.latestTick - maxLatestTickMove;
        }

        return (newLatestTick, false);
    }

    function _rollover(
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.AccumulateCache memory cache,
        ICoverPoolStructs.PoolState memory pool,
        bool isPool0
    ) internal pure returns (
        ICoverPoolStructs.AccumulateCache memory,
        ICoverPoolStructs.PoolState memory
    ) {
        //TODO: add syncing fee
        if (pool.liquidity == 0) {
            return (cache, pool);
        }
        uint160 crossPrice; uint160 accumPrice; uint160 currentPrice;
        if (isPool0) {
            crossPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross0);
            int24 nextTickToAccum = (cache.nextTickToAccum0 < cache.stopTick0)
                                        ? cache.stopTick0
                                        : cache.nextTickToAccum0;
            accumPrice = TickMath.getSqrtRatioAtTick(nextTickToAccum);
            // check for multiple auction skips
            if (cache.nextTickToCross0 == state.latestTick && cache.nextTickToCross0 - nextTickToAccum > state.tickSpread) {
                uint160 spreadPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross0 - state.tickSpread);
                /// @dev - amountOutDeltaMax accounted for down below
                cache.deltas0.amountOutDelta += uint128(DyDxMath.getDx(pool.liquidity, accumPrice, spreadPrice, false));
            }
            currentPrice = pool.price;
            // if pool.price the bounds set currentPrice to start of auction
            if (!(pool.price > accumPrice && pool.price < crossPrice)) currentPrice = accumPrice;
            // if auction is current and fully filled => set currentPrice to crossPrice
            if (state.latestTick == cache.nextTickToCross0 && crossPrice == pool.price) currentPrice = crossPrice;
        } else {
            crossPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross1);
            int24 nextTickToAccum = (cache.nextTickToAccum1 > cache.stopTick1)
                                        ? cache.stopTick1
                                        : cache.nextTickToAccum1;
            accumPrice = TickMath.getSqrtRatioAtTick(nextTickToAccum);
            // check for multiple auction skips
            if (cache.nextTickToCross1 == state.latestTick && nextTickToAccum - cache.nextTickToCross1 > state.tickSpread) {
                uint160 spreadPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross1 + state.tickSpread);
                /// @dev - DeltaMax values accounted for down below
                cache.deltas1.amountOutDelta += uint128(DyDxMath.getDy(pool.liquidity, spreadPrice, accumPrice, false));
            }
            currentPrice = pool.price;
            if (!(pool.price < accumPrice && pool.price > crossPrice)) currentPrice = accumPrice;
            if (state.latestTick == cache.nextTickToCross1 && crossPrice == pool.price) currentPrice = crossPrice;
        }

        //handle liquidity rollover
        if (isPool0) {
            // amountIn pool did not receive
            uint128 amountInDelta;
            uint128 amountInDeltaMax  = uint128(DyDxMath.getDy(pool.liquidity, accumPrice, crossPrice, false));
            amountInDelta       = pool.amountInDelta;
            amountInDeltaMax   -= (amountInDeltaMax < pool.amountInDeltaMaxClaimed) ? amountInDeltaMax 
                                                                                    : pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            // amountOut pool has leftover
            uint128 amountOutDelta    = uint128(DyDxMath.getDx(pool.liquidity, currentPrice, crossPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDx(pool.liquidity, accumPrice, crossPrice, false));
            amountOutDeltaMax -= (amountOutDeltaMax < pool.amountOutDeltaMaxClaimed) ? amountOutDeltaMax
                                                                                     : pool.amountOutDeltaMaxClaimed;
            pool.amountOutDeltaMaxClaimed = 0;

            // update cache deltas
            cache.deltas0.amountInDelta     += amountInDelta;
            cache.deltas0.amountInDeltaMax  += amountInDeltaMax;
            cache.deltas0.amountOutDelta    += amountOutDelta;
            cache.deltas0.amountOutDeltaMax += amountOutDeltaMax;
        } else {
            // amountIn pool did not receive
            uint128 amountInDelta;
            uint128 amountInDeltaMax = uint128(DyDxMath.getDx(pool.liquidity, crossPrice, accumPrice, false));
            amountInDelta       = pool.amountInDelta;
            amountInDeltaMax   -= (amountInDeltaMax < pool.amountInDeltaMaxClaimed) ? amountInDeltaMax 
                                                                                    : pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            // amountOut pool has leftover
            uint128 amountOutDelta    = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, currentPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, accumPrice, false));
            amountOutDeltaMax -= (amountOutDeltaMax < pool.amountOutDeltaMaxClaimed) ? amountOutDeltaMax
                                                                                     : pool.amountOutDeltaMaxClaimed;
            pool.amountOutDeltaMaxClaimed = 0;

            // update cache deltas
            cache.deltas1.amountInDelta     += amountInDelta;
            cache.deltas1.amountInDeltaMax  += amountInDeltaMax;
            cache.deltas1.amountOutDelta    += amountOutDelta;
            cache.deltas1.amountOutDeltaMax += amountOutDeltaMax;
        }
        return (cache, pool);
    }

    function _accumulate(
        ICoverPoolStructs.Tick memory crossTick,
        ICoverPoolStructs.Tick memory accumTick,
        ICoverPoolStructs.Deltas memory deltas,
        bool updateAccumDeltas
    ) internal pure returns (
        ICoverPoolStructs.AccumulateOutputs memory
    ) {

        if (crossTick.amountInDeltaMaxStashed > 0) {
            /// @dev - else we migrate carry deltas onto cache
            // add carry amounts to cache
            (crossTick, deltas) = Deltas.unstash(crossTick, deltas);
        }
        if (updateAccumDeltas) {
            // migrate carry deltas from cache to accum tick
            //TODO: burn delta max minuses
            ICoverPoolStructs.Deltas memory accumDeltas;
            if (accumTick.amountInDeltaMaxMinus > 0) {
                // calculate percent of deltas left on tick
                uint256 percentInOnTick  = uint256(accumTick.amountInDeltaMaxMinus)  * 1e38 / (deltas.amountInDeltaMax);
                uint256 percentOutOnTick = uint256(accumTick.amountOutDeltaMaxMinus) * 1e38 / (deltas.amountOutDeltaMax);
                // transfer deltas to the accum tick
                (deltas, accumDeltas) = Deltas.transfer(deltas, accumDeltas, percentInOnTick, percentOutOnTick);
                
                // burn tick deltas maxes from cache
                deltas = Deltas.burnMaxCache(deltas, accumTick);
                
                // empty delta max minuses into delta max
                accumDeltas.amountInDeltaMax  += accumTick.amountInDeltaMaxMinus;
                accumDeltas.amountOutDeltaMax += accumTick.amountOutDeltaMaxMinus;
                accumTick.amountInDeltaMaxMinus  = 0;
                accumTick.amountOutDeltaMaxMinus = 0;
                accumTick.deltas = accumDeltas;
            }
        }
        // remove all liquidity
        crossTick.liquidityDelta = 0;

        // clear out stash
        crossTick.amountInDeltaMaxStashed  = 0;
        crossTick.amountOutDeltaMaxStashed = 0;

        return
            ICoverPoolStructs.AccumulateOutputs(
                /// @dev - deltas are returned here and should be updated in cache
                deltas,
                crossTick,
                accumTick
            );
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        ICoverPoolStructs.TickMap storage tickMap,
        int128 liquidityDelta,
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint128 currentLiquidity,
        bool zeroForOne
    ) internal view returns (
        uint128,
        int24,
        int24
    )
    {
        nextTickToCross = nextTickToAccum;

        if (liquidityDelta > 0) {
            currentLiquidity += uint128(liquidityDelta);
        } else {
            currentLiquidity -= uint128(-liquidityDelta);
        }
        if (zeroForOne) {
            nextTickToAccum = TickMap.previous(tickMap, nextTickToAccum);
        } else {
            nextTickToAccum = TickMap.next(tickMap, nextTickToAccum);
        }
        return (currentLiquidity, nextTickToCross, nextTickToAccum);
    }

    function _stash(
        ICoverPoolStructs.Tick memory stashTick,
        ICoverPoolStructs.AccumulateCache memory cache,
        uint128 currentLiquidity,
        bool isPool0
    ) internal pure returns (ICoverPoolStructs.Tick memory) {
        // return since there is nothing to update
        if (currentLiquidity == 0) return (stashTick);
        // handle deltas
        ICoverPoolStructs.Deltas memory deltas = isPool0 ? cache.deltas0 : cache.deltas1;
        if (deltas.amountInDeltaMax > 0) {
            (deltas, stashTick) = Deltas.stash(deltas, stashTick);
        }
        stashTick.liquidityDelta += int128(currentLiquidity);
        return (stashTick);
    }
}
