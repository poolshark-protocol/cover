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
import 'hardhat/console.sol';

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
        ICoverPoolStructs.GlobalState memory state
    ) external returns (
        ICoverPoolStructs.GlobalState memory,
        ICoverPoolStructs.PoolState memory,
        ICoverPoolStructs.PoolState memory
    )
    {
        int24 newLatestTick;
        {
            bool earlyReturn;
            (newLatestTick, earlyReturn) = _syncTick(state);
            if (earlyReturn) {
                return (state, pool0, pool1);
            }
            // else we have a TWAP update
        }

        // increase epoch counter
        state.accumEpoch += 1;

        // Get the next tick number
        int24 nextTick0 = state.latestTick - state.tickSpread;
        int24 nextTick1 = state.latestTick + state.tickSpread;

        // Check if the nextTick doesn't exist
        TickMap.set(tickMap, nextTick0);
        TickMap.set(tickMap, nextTick1);

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
                 && ticks0[cache.nextTickToAccum0].liquidityDeltaMinus > 0) {
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
            cache.deltas0 = outputs.deltas;
            ticks0[cache.nextTickToCross0] = outputs.crossTick;
            ticks0[cache.nextTickToAccum0] = outputs.accumTick;
            
            // keep looping until accumulation reaches stopTick0 
            if (cache.nextTickToAccum0 > cache.stopTick0) {
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
            if (newLatestTick > state.latestTick) {
                // create stopTick0 if necessary
                if (cache.nextTickToAccum0 != cache.stopTick0) {
                    TickMap.set(tickMap, cache.stopTick0);
                }
            }
            ICoverPoolStructs.Tick memory stopTick0 = ticks0[cache.stopTick0];
            // checkpoint at stopTick0
            (stopTick0) = _stash(
                stopTick0,
                cache,
                pool0.liquidity,
                true
            );
            if (newLatestTick < state.latestTick) {
                if (cache.nextTickToAccum0 >= cache.stopTick0) {
                    // cross in and activate next auction
                    (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                        tickMap,
                        ticks0[cache.nextTickToAccum0].liquidityDelta,
                        cache.nextTickToCross0,
                        cache.nextTickToAccum0,
                        pool0.liquidity,
                        true
                    );
                }
                if (cache.nextTickToCross0 != newLatestTick) {
                    // create newLatestTick
                    TickMap.set(tickMap, cache.stopTick0);
                }
            }
            // zero out tick liquidity
            stopTick0.liquidityDelta += int128(
                stopTick0.liquidityDeltaMinus
            );
                    
            stopTick0.liquidityDeltaMinus = 0;
            EpochMap.set(tickMap, cache.stopTick0, state.accumEpoch);
            ticks0[cache.stopTick0] = stopTick0;
        }

        while (true) {
            // rollover deltas pool1
            (cache, pool1) = _rollover(state, cache, pool1, false);
            // accumulate deltas pool1
            if (cache.nextTickToAccum0 > cache.stopTick0 
                 && ticks0[cache.nextTickToAccum0].liquidityDeltaMinus > 0) {
                EpochMap.set(tickMap, cache.nextTickToAccum0, state.accumEpoch);
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
                cache.deltas1 = outputs.deltas;
                ticks1[cache.nextTickToCross1] = outputs.crossTick;
                ticks1[cache.nextTickToAccum1] = outputs.accumTick;
            }

            // keep looping until accumulation reaches stopTick1 
            if (cache.nextTickToAccum1 < cache.stopTick1) {
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
            if (newLatestTick < state.latestTick) {
                // create stopTick1 if necessary
                if (cache.nextTickToAccum1 != cache.stopTick1) {
                    TickMap.set(tickMap, cache.stopTick1);
                }
            }
            ICoverPoolStructs.Tick memory stopTick1 = ticks1[cache.stopTick1];
            // update deltas on stopTick
            (stopTick1) = _stash(
                stopTick1,
                cache,
                pool1.liquidity,
                false
            );
            if (newLatestTick > state.latestTick) {
                // create newLatestTick
                if (cache.nextTickToAccum1 != newLatestTick) {
                    TickMap.set(tickMap, cache.stopTick1);
                }
                // is there a tick in between?
                if (cache.nextTickToAccum1 <= cache.stopTick1) {
                    (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                        tickMap,
                        ticks1[cache.nextTickToAccum1].liquidityDelta,
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        pool1.liquidity,
                        false
                    );
                }
                // clear pool0 liquidity if latestTick increases
                pool0.liquidity = 0;
            } else {
                // clear pool1 liquidity if latestTick decreases
                pool1.liquidity = 0;
            }
            stopTick1.liquidityDelta += int128(
                stopTick1.liquidityDeltaMinus
            );
            stopTick1.liquidityDeltaMinus = 0;
            ticks1[cache.stopTick1] = stopTick1;
            EpochMap.set(tickMap, cache.stopTick1, state.accumEpoch);
        }
        //TODO: only set price on one side
        // set pool price based on newLatestTick
        pool0.price = TickMath.getSqrtRatioAtTick(newLatestTick - state.tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(newLatestTick + state.tickSpread);

        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.number - state.genesisBlock);
        state.latestTick = newLatestTick;
        state.latestPrice = TickMath.getSqrtRatioAtTick(newLatestTick);
    
        return (state, pool0, pool1);
    }

    function _syncTick(
        ICoverPoolStructs.GlobalState memory state
    ) internal view returns(
        int24 newLatestTick,
        bool
    ) {
        // update last block checked
        if(state.lastBlock == uint32(block.number) - state.genesisBlock) {
            return (0, true);
        }
        state.lastBlock = uint32(block.number) - state.genesisBlock;
        // check auctions elapsed
        int32 auctionsElapsed = int32((state.lastBlock - state.auctionStart) / state.auctionLength);
        if (auctionsElapsed == 0) {
            return (0, true);
        }

        newLatestTick = TwapOracle.calculateAverageTick(state.inputPool, state.twapLength);
        newLatestTick = newLatestTick / state.tickSpread * state.tickSpread; // even multiple of tickSpread

        // only accumulate if latestTick needs to move
        // tickSpread = 40; newLatest = 85; oldLatest = 80;
        // newLatest / 40 = 2; 80 / 40 = 2
        //  => 40
        // 10 => 20 => 10 => 20
        // tickSpacing 10
        // > 50%
        // 30 => 40 => 80 - 40
        // 10 => 0
        // 1.00 and 2.00 => $100 => 99.20
        // 0.10 bps off on one tick
        // latestTick hits 40
        /// if the sample moves to 10, do you cut the auction length in half?
        if (newLatestTick == state.latestTick) {
            return (0, true);
        }

        // rate-limiting tick move
        int24 maxLatestTickMove =  int24(state.tickSpread * auctionsElapsed);

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
    ) internal view returns (
        ICoverPoolStructs.AccumulateCache memory,
        ICoverPoolStructs.PoolState memory
    ) {
        //TODO: add syncing fee
        if (pool.liquidity == 0) {
            /// @auditor - deltas should be zeroed out here
            return (cache, pool);
        }
        //crossPrice based on next tick in direction of swap
        uint160 crossPrice = TickMath.getSqrtRatioAtTick(
            isPool0 ? cache.nextTickToCross0 : cache.nextTickToCross1
        );
        uint160 accumPrice;
        {
            /// @dev - set accum price to either stopTick or nextTickToAccum
            int24 nextTickToAccum;
            if (isPool0) {
                nextTickToAccum = (cache.nextTickToAccum0 < cache.stopTick0)
                    ? cache.stopTick0
                    : cache.nextTickToAccum0;
            } else {
                nextTickToAccum = (cache.nextTickToAccum1 > cache.stopTick1)
                    ? cache.stopTick1
                    : cache.nextTickToAccum1;
            }
            accumPrice = TickMath.getSqrtRatioAtTick(nextTickToAccum);
        }
        uint160 currentPrice = pool.price;
        // full tick unfilled vs. partial tick unfilled
        if (isPool0){
            // if we're outside the bounds set currentPrice to start of auction
            // this is for skipping multiple auctions in one syncLatest() call
            if (!(pool.price > accumPrice && pool.price < crossPrice)) currentPrice = accumPrice;
            // if auction is current and fully filled => set currentPrice to crossPrice
            if (state.latestTick == cache.nextTickToCross0 && crossPrice == pool.price) currentPrice = crossPrice;
        } else{
            if (!(pool.price < accumPrice && pool.price > crossPrice)) currentPrice = accumPrice;
            if (state.latestTick == cache.nextTickToCross1 && crossPrice == pool.price) currentPrice = crossPrice;
        }

        //handle liquidity rollover
        if (isPool0) {
            // amountIn pool did not receive
            uint128 amountInDelta;
            uint128 amountInDeltaMax  = uint128(DyDxMath.getDy(pool.liquidity, accumPrice, crossPrice, false));
            amountInDelta       = pool.amountInDelta;
            amountInDeltaMax   -= pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            // amountOut pool has leftover
            uint128 amountOutDelta    = uint128(DyDxMath.getDx(pool.liquidity, currentPrice, crossPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDx(pool.liquidity, accumPrice, crossPrice, false));
            amountOutDeltaMax -= pool.amountOutDeltaMaxClaimed;
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
            amountInDeltaMax   -= pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            /// @dev - if auction fully filled amountOutDelta should be zero
            // if(state.latestTick == cache.nextTickToCross1 && crossPrice == pool.price) {
            //     currentPrice = pool.price;
            // }

            // amountOut pool has leftover
            uint128 amountOutDelta   = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, currentPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, accumPrice, false));
            amountOutDeltaMax -= pool.amountOutDeltaMaxClaimed;
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
    ) internal view returns (
        ICoverPoolStructs.AccumulateOutputs memory
    ) {

        if (crossTick.amountInDeltaMaxStashed > 0) {
            /// @dev - else we migrate carry deltas onto cache
            // add carry amounts to cache
            (crossTick, deltas) = Deltas.unstash(crossTick, deltas);
        }
        if (updateAccumDeltas) {
            // migrate carry deltas from cache to accum tick
            ICoverPoolStructs.Deltas memory accumDeltas = accumTick.deltas;
            if (deltas.amountInDeltaMax > 0) {
                if (accumDeltas.amountInDeltaMax > 0) {
                    uint256 percentInOnTick  = uint256(accumDeltas.amountInDeltaMax) * 1e38 / (deltas.amountInDeltaMax);
                    uint256 percentOutOnTick = uint256(accumDeltas.amountOutDeltaMax) * 1e38 / (deltas.amountOutDeltaMax);
                    // transfer 
                    (deltas, accumDeltas) = Deltas.transfer(deltas, accumDeltas, percentInOnTick, percentOutOnTick);
                    // burn delta maxes in cache
                    deltas = Deltas.burnMax(deltas, accumDeltas);
                    accumTick.deltas = accumDeltas;
                }
            }
        }
        // remove all liquidity
        crossTick.liquidityDelta = 0;
        crossTick.liquidityDeltaMinus = 0;

        // clear out stash
        crossTick.amountInDeltaMaxStashed  = 0;
        crossTick.amountOutDeltaMaxStashed = 0;

        return
            ICoverPoolStructs.AccumulateOutputs(
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
    ) internal view returns (ICoverPoolStructs.Tick memory) {
        // return since there is nothing to update
        if (currentLiquidity == 0) return (stashTick);
        // handle deltas
        ICoverPoolStructs.Deltas memory deltas = isPool0 ? cache.deltas0 : cache.deltas1;
        if (deltas.amountInDeltaMax > 0) {
            (deltas, stashTick) = Deltas.stash(deltas, stashTick);
        }
        stashTick.liquidityDelta += int128(currentLiquidity);
        stashTick.liquidityDelta -= int128(stashTick.liquidityDeltaMinus);
        return (stashTick);
    }
}
