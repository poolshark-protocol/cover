// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import './math/DyDxMath.sol';
import '../interfaces/ITwapSource.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './Deltas.sol';
import './TickMap.sol';
import './EpochMap.sol';

library Epochs {
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    event SyncFeesCollected(
        address collector,
        uint128 token0Amount,
        uint128 token1Amount
    );

    event FinalDeltasAccumulated(
        bool isPool0,
        int24 accumTick,
        int24 crossTick,
        uint128 amountInDelta,
        uint128 amountOutDelta
    );

    event StashDeltasAccumulated(
        bool isPool0,
        uint128 amountInDelta,
        uint128 amountOutDelta,
        uint128 amountInDeltaMaxStashed,
        uint128 amountOutDeltaMaxStashed
    );

    function simulateSync(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks0,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks1,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.PoolState memory pool0,
        ICoverPoolStructs.PoolState memory pool1,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        ICoverPoolStructs.GlobalState memory,
        ICoverPoolStructs.SyncFees memory,
        ICoverPoolStructs.PoolState memory,
        ICoverPoolStructs.PoolState memory
    ) {
        int24 newLatestTick;
        {
            bool earlyReturn;
            (newLatestTick, earlyReturn) = _syncTick(state, constants);
            if (earlyReturn) {
                return (state, ICoverPoolStructs.SyncFees(0, 0), pool0, pool1);
            }
            // else we have a TWAP update
        }

        // setup cache
        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            deltas0: ICoverPoolStructs.Deltas(0, 0, 0, 0), // deltas for pool0
            deltas1: ICoverPoolStructs.Deltas(0, 0, 0, 0),  // deltas for pool1
            syncFees: ICoverPoolStructs.SyncFees(0, 0),
            nextTickToCross0: state.latestTick, // above
            nextTickToCross1: state.latestTick, // below
            nextTickToAccum0: TickMap.previous(tickMap, state.latestTick, constants.tickSpread), // below
            nextTickToAccum1: TickMap.next(tickMap, state.latestTick, constants.tickSpread),     // above
            stopTick0: (newLatestTick > state.latestTick) // where we do stop for pool0 sync
                ? state.latestTick - constants.tickSpread
                : newLatestTick, 
            stopTick1: (newLatestTick > state.latestTick) // where we do stop for pool1 sync
                ? newLatestTick
                : state.latestTick + constants.tickSpread
        });

        while (true) {
            // rollover and calculate sync fees
            (cache, pool0) = _rollover(state, cache, pool0, constants, true);
            // keep looping until accumulation reaches stopTick0 
            if (cache.nextTickToAccum0 >= cache.stopTick0) {
                (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                    tickMap,
                    ticks0[cache.nextTickToAccum0].liquidityDelta,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true,
                    constants.tickSpread
                );
            } else break;
        }

        while (true) {
            (cache, pool1) = _rollover(state, cache, pool1, constants, false);
            // keep looping until accumulation reaches stopTick1 
            if (cache.nextTickToAccum1 <= cache.stopTick1) {
                (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                    tickMap,
                    ticks1[cache.nextTickToAccum1].liquidityDelta,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false,
                    constants.tickSpread
                );
            } else break;
        }

        // update ending pool price for fully filled auction
        state.latestPrice = TickMath.getSqrtRatioAtTick(newLatestTick);
        
        // set pool price and liquidity
        if (newLatestTick > state.latestTick) {
            pool0.liquidity = 0;
            pool0.price = state.latestPrice;
            pool1.price = TickMath.getSqrtRatioAtTick(newLatestTick + constants.tickSpread);
        } else {
            pool1.liquidity = 0;
            pool0.price = TickMath.getSqrtRatioAtTick(newLatestTick - constants.tickSpread);
            pool1.price = state.latestPrice;
        }
        
        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.timestamp) - constants.genesisTime;
        state.latestTick = newLatestTick;
    
        return (state, cache.syncFees, pool0, pool1);
    }

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
        ICoverPoolStructs.SyncFees memory,
        ICoverPoolStructs.PoolState memory,
        ICoverPoolStructs.PoolState memory
    )
    {
        int24 newLatestTick;
        {
            bool earlyReturn;
            (newLatestTick, earlyReturn) = _syncTick(state, constants);
            if (earlyReturn) {
                return (state, ICoverPoolStructs.SyncFees(0,0), pool0, pool1);
            }
            // else we have a TWAP update
        }

        // increase epoch counter
        state.accumEpoch += 1;

        // setup cache
        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            deltas0: ICoverPoolStructs.Deltas(0, 0, 0, 0), // deltas for pool0
            deltas1: ICoverPoolStructs.Deltas(0, 0, 0, 0),  // deltas for pool1
            syncFees: ICoverPoolStructs.SyncFees(0,0),
            nextTickToCross0: state.latestTick, // above
            nextTickToCross1: state.latestTick, // below
            nextTickToAccum0: TickMap.previous(tickMap, state.latestTick, constants.tickSpread), // below
            nextTickToAccum1: TickMap.next(tickMap, state.latestTick, constants.tickSpread),     // above
            stopTick0: (newLatestTick > state.latestTick) // where we do stop for pool0 sync
                ? state.latestTick - constants.tickSpread
                : newLatestTick, 
            stopTick1: (newLatestTick > state.latestTick) // where we do stop for pool1 sync
                ? newLatestTick
                : state.latestTick + constants.tickSpread
        });

        while (true) {
            // get values from current auction
            (cache, pool0) = _rollover(state, cache, pool0, constants, true);
            if (cache.nextTickToAccum0 > cache.stopTick0 
                 && ticks0[cache.nextTickToAccum0].amountInDeltaMaxMinus > 0) {
                EpochMap.set(tickMap, cache.nextTickToAccum0, state.accumEpoch, constants.tickSpread);
            }
            // accumulate to next tick
            ICoverPoolStructs.AccumulateParams memory params = ICoverPoolStructs.AccumulateParams({
                deltas: cache.deltas0,
                crossTick: ticks0[cache.nextTickToCross0],
                accumTick: ticks0[cache.nextTickToAccum0],
                updateAccumDeltas: newLatestTick > state.latestTick
                                            ? cache.nextTickToAccum0 == cache.stopTick0
                                            : cache.nextTickToAccum0 >= cache.stopTick0,
                isPool0: true
            });
            params = _accumulate(
                cache,
                params
            );
            /// @dev - deltas in cache updated after _accumulate
            cache.deltas0 = params.deltas;
            ticks0[cache.nextTickToCross0] = params.crossTick;
            ticks0[cache.nextTickToAccum0] = params.accumTick;
            
            // keep looping until accumulation reaches stopTick0 
            if (cache.nextTickToAccum0 >= cache.stopTick0) {
                (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                    tickMap,
                    ticks0[cache.nextTickToAccum0].liquidityDelta,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true,
                    constants.tickSpread
                );
            } else break;
        }
        // pool0 checkpoint
        {
            // create stopTick0 if necessary
            if (cache.nextTickToAccum0 != cache.stopTick0) {
                TickMap.set(tickMap, cache.stopTick0, constants.tickSpread);
            }
            ICoverPoolStructs.Tick memory stopTick0 = ticks0[cache.stopTick0];
            // checkpoint at stopTick0
            (stopTick0) = _stash(
                stopTick0,
                cache,
                pool0.liquidity,
                true
            );
            EpochMap.set(tickMap, cache.stopTick0, state.accumEpoch, constants.tickSpread);
            ticks0[cache.stopTick0] = stopTick0;
        }

        while (true) {
            // rollover deltas pool1
            (cache, pool1) = _rollover(state, cache, pool1, constants, false);
            // accumulate deltas pool1
            if (cache.nextTickToAccum1 < cache.stopTick1 
                 && ticks1[cache.nextTickToAccum1].amountInDeltaMaxMinus > 0) {
                EpochMap.set(tickMap, cache.nextTickToAccum1, state.accumEpoch, constants.tickSpread);
            }
            {
                ICoverPoolStructs.AccumulateParams memory params = ICoverPoolStructs.AccumulateParams({
                    deltas: cache.deltas1,
                    crossTick: ticks1[cache.nextTickToCross1],
                    accumTick: ticks1[cache.nextTickToAccum1],
                    updateAccumDeltas: newLatestTick > state.latestTick
                                                ? cache.nextTickToAccum1 <= cache.stopTick1
                                                : cache.nextTickToAccum1 == cache.stopTick1,
                    isPool0: false
                });
                params = _accumulate(
                    cache,
                    params
                );
                /// @dev - deltas in cache updated after _accumulate
                cache.deltas1 = params.deltas;
                ticks1[cache.nextTickToCross1] = params.crossTick;
                ticks1[cache.nextTickToAccum1] = params.accumTick;
            }
            // keep looping until accumulation reaches stopTick1 
            if (cache.nextTickToAccum1 <= cache.stopTick1) {
                (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                    tickMap,
                    ticks1[cache.nextTickToAccum1].liquidityDelta,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false,
                    constants.tickSpread
                );
            } else break;
        }
        // pool1 checkpoint
        {
            // create stopTick1 if necessary
            if (cache.nextTickToAccum1 != cache.stopTick1) {
                TickMap.set(tickMap, cache.stopTick1, constants.tickSpread);
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
            EpochMap.set(tickMap, cache.stopTick1, state.accumEpoch, constants.tickSpread);
        }
        // update ending pool price for fully filled auction
        state.latestPrice = TickMath.getSqrtRatioAtTick(newLatestTick);
        
        // set pool price and liquidity
        if (newLatestTick > state.latestTick) {
            pool0.liquidity = 0;
            pool0.price = state.latestPrice;
            pool1.price = TickMath.getSqrtRatioAtTick(newLatestTick + constants.tickSpread);
        } else {
            pool1.liquidity = 0;
            pool0.price = TickMath.getSqrtRatioAtTick(newLatestTick - constants.tickSpread);
            pool1.price = state.latestPrice;
        }
        
        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.timestamp) - constants.genesisTime;
        state.latestTick = newLatestTick;

        if (cache.syncFees.token0 > 0 || cache.syncFees.token1 > 0) {
            emit SyncFeesCollected(msg.sender, cache.syncFees.token0, cache.syncFees.token1);
        }
    
        return (state, cache.syncFees, pool0, pool1);
    }

    function _syncTick(
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants
    ) internal view returns(
        int24 newLatestTick,
        bool
    ) {
        // update last block checked
        if(state.lastTime == uint32(block.timestamp) - constants.genesisTime) {
            return (state.latestTick, true);
        }
        state.lastTime = uint32(block.timestamp) - constants.genesisTime;
        // check auctions elapsed
        int32 auctionsElapsed = int32((uint32(block.timestamp) - constants.genesisTime - state.auctionStart) / constants.auctionLength);

        if (auctionsElapsed == 0) {
            return (state.latestTick, true);
        }
        newLatestTick = ITwapSource(constants.twapSource).calculateAverageTick(constants.inputPool, constants.twapLength);
        /// @dev - shift up/down one quartile to put pool ahead of TWAP
        if (newLatestTick > state.latestTick)
             newLatestTick += constants.tickSpread / 4;
        else if (newLatestTick <= state.latestTick - 3 * constants.tickSpread / 4)
             newLatestTick -= constants.tickSpread / 4;
        newLatestTick = newLatestTick / constants.tickSpread * constants.tickSpread; // even multiple of tickSpread
        if (newLatestTick == state.latestTick) {
            return (state.latestTick, true);
        }

        // rate-limiting tick move
        int24 maxLatestTickMove = int24(constants.tickSpread * auctionsElapsed);

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
        ICoverPoolStructs.Immutables memory constants,
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
            if (cache.nextTickToCross0 == state.latestTick && cache.nextTickToCross0 - nextTickToAccum > constants.tickSpread) {
                uint160 spreadPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross0 - constants.tickSpread);
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
            if (cache.nextTickToCross1 == state.latestTick && nextTickToAccum - cache.nextTickToCross1 > constants.tickSpread) {
                uint160 spreadPrice = TickMath.getSqrtRatioAtTick(cache.nextTickToCross1 + constants.tickSpread);
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

            // update cache in deltas
            cache.deltas0.amountInDelta     += amountInDelta;
            cache.deltas0.amountInDeltaMax  += amountInDeltaMax;

            // calculate sync fee
            uint128 syncFeeAmount = constants.syncFee * amountOutDelta / 1e6;
            cache.syncFees.token0 += syncFeeAmount;
            amountOutDelta -= syncFeeAmount;

            // update cache out deltas
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

            // update cache in deltas
            cache.deltas1.amountInDelta     += amountInDelta;
            cache.deltas1.amountInDeltaMax  += amountInDeltaMax;

            // calculate sync fee
            //TODO: only take syncFee if auctionLength expired
            uint128 syncFeeAmount = constants.syncFee * amountOutDelta / 1e6;
            cache.syncFees.token1 += syncFeeAmount;
            amountOutDelta -= syncFeeAmount;    

            // update cache out deltas
            cache.deltas1.amountOutDelta    += amountOutDelta;
            cache.deltas1.amountOutDeltaMax += amountOutDeltaMax;
        }
        return (cache, pool);
    }

    function _accumulate(
        ICoverPoolStructs.AccumulateCache memory cache,
        ICoverPoolStructs.AccumulateParams memory params
    ) internal returns (
        ICoverPoolStructs.AccumulateParams memory
    ) {
        if (params.crossTick.amountInDeltaMaxStashed > 0) {
            /// @dev - else we migrate carry deltas onto cache
            // add carry amounts to cache
            (params.crossTick, params.deltas) = Deltas.unstash(params.crossTick, params.deltas);
        }
        if (params.updateAccumDeltas) {
            // migrate carry deltas from cache to accum tick
            ICoverPoolStructs.Deltas memory accumDeltas;
            if (params.accumTick.amountInDeltaMaxMinus > 0) {
                // calculate percent of deltas left on tick
                uint256 percentInOnTick  = uint256(params.accumTick.amountInDeltaMaxMinus)  * 1e38 / (params.deltas.amountInDeltaMax);
                uint256 percentOutOnTick = uint256(params.accumTick.amountOutDeltaMaxMinus) * 1e38 / (params.deltas.amountOutDeltaMax);
                // transfer deltas to the accum tick
                (params.deltas, accumDeltas) = Deltas.transfer(params.deltas, accumDeltas, percentInOnTick, percentOutOnTick);
                
                // burn tick deltas maxes from cache
                params.deltas = Deltas.burnMaxCache(params.deltas, params.accumTick);
                
                // empty delta max minuses into delta max
                accumDeltas.amountInDeltaMax  += params.accumTick.amountInDeltaMaxMinus;
                accumDeltas.amountOutDeltaMax += params.accumTick.amountOutDeltaMaxMinus;

                if (params.isPool0) {
                    emit FinalDeltasAccumulated(
                        params.isPool0,
                        cache.nextTickToCross0,
                        cache.nextTickToAccum0,
                        accumDeltas.amountInDelta,
                        accumDeltas.amountOutDelta
                    );
                } else {
                    emit FinalDeltasAccumulated(
                        params.isPool0,
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        accumDeltas.amountInDelta,
                        accumDeltas.amountOutDelta
                    );
                }
                params.accumTick.amountInDeltaMaxMinus  = 0;
                params.accumTick.amountOutDeltaMaxMinus = 0;
                params.accumTick.deltas = accumDeltas;
            }
        }
        // remove all liquidity
        params.crossTick.liquidityDelta = 0;

        // clear out stash
        params.crossTick.amountInDeltaMaxStashed  = 0;
        params.crossTick.amountOutDeltaMaxStashed = 0;

        return params;
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        ICoverPoolStructs.TickMap storage tickMap,
        int128 liquidityDelta,
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint128 currentLiquidity,
        bool zeroForOne,
        int16 tickSpread
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
            nextTickToAccum = TickMap.previous(tickMap, nextTickToAccum, tickSpread);
        } else {
            nextTickToAccum = TickMap.next(tickMap, nextTickToAccum, tickSpread);
        }
        return (currentLiquidity, nextTickToCross, nextTickToAccum);
    }

    function _stash(
        ICoverPoolStructs.Tick memory stashTick,
        ICoverPoolStructs.AccumulateCache memory cache,
        uint128 currentLiquidity,
        bool isPool0
    ) internal returns (ICoverPoolStructs.Tick memory) {
        // return since there is nothing to update
        if (currentLiquidity == 0) return (stashTick);
        // handle deltas
        ICoverPoolStructs.Deltas memory deltas = isPool0 ? cache.deltas0 : cache.deltas1;
        //TODO: event emit specifying amounts stashed
        emit StashDeltasAccumulated(
            isPool0,
            deltas.amountInDelta,
            deltas.amountOutDelta,
            deltas.amountInDeltaMax,
            deltas.amountOutDeltaMax
        );
        if (deltas.amountInDeltaMax > 0) {
            (deltas, stashTick) = Deltas.stash(deltas, stashTick);
        }
        stashTick.liquidityDelta += int128(currentLiquidity);
        return (stashTick);
    }
}
