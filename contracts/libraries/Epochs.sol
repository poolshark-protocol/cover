// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import './DyDxMath.sol';
import './TwapOracle.sol';
import '../interfaces/IRangePool.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './Deltas.sol';
import 'hardhat/console.sol';

library Epochs {
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    error InfiniteTickLoop0(int24);
    error InfiniteTickLoop1(int24);

    function syncLatest(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks0,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks1,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.PoolState memory pool0,
        ICoverPoolStructs.PoolState memory pool1,
        ICoverPoolStructs.GlobalState memory state
    )
        external
        returns (
            ICoverPoolStructs.GlobalState memory,
            ICoverPoolStructs.PoolState memory,
            ICoverPoolStructs.PoolState memory
        )
    {
        // update last block checked
        int24 nextLatestTick = TwapOracle.calculateAverageTick(state.inputPool, state.twapLength);
        state.lastBlock = uint32(block.number);
        // only accumulate if latestTick needs to move
        if (nextLatestTick / (state.tickSpread) == state.latestTick / (state.tickSpread)) {
            return (state, pool0, pool1);
        }
        // console.log("-- START ACCUMULATE LAST BLOCK --");
        state.accumEpoch += 1;

        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            nextTickToCross0: state.latestTick,
            nextTickToCross1: state.latestTick,
            nextTickToAccum0: tickNodes[state.latestTick].previousTick, /// create tick if L > 0 and nextLatestTick != latestTick + tickSpread
            nextTickToAccum1: tickNodes[state.latestTick].nextTick, /// create tick if L > 0 and nextLatestTick != latestTick - tickSpread
            stopTick0: (nextLatestTick > state.latestTick)
                ? state.latestTick - state.tickSpread
                : nextLatestTick,
            stopTick1: (nextLatestTick > state.latestTick)
                ? nextLatestTick
                : state.latestTick + state.tickSpread,
            deltas0: ICoverPoolStructs.Deltas(0, 0, 0, 0), /// @dev - initialize to what was already on the pool
            deltas1: ICoverPoolStructs.Deltas(0, 0, 0, 0) /// @dev - initialize to what was already on the pool
        });

        // loop over ticks0 until stopTick0
        while (true) {
            // rollover deltas from current auction
            (cache, pool0) = _rollover(cache, pool0, true);
            // accumulate to next tick
            ICoverPoolStructs.AccumulateOutputs memory outputs;
            outputs = _accumulate(
                tickNodes[cache.nextTickToAccum0],
                tickNodes[cache.nextTickToCross0],
                ticks0[cache.nextTickToCross0],
                ticks0[cache.nextTickToAccum0],
                cache.deltas0,
                state.accumEpoch,
                true,
                nextLatestTick > state.latestTick
                    ? cache.nextTickToAccum0 < cache.stopTick0
                    : cache.nextTickToAccum0 > cache.stopTick0
            );
            cache.deltas0 = outputs.deltas;
            tickNodes[cache.nextTickToAccum0] = outputs.accumTickNode;
            tickNodes[cache.nextTickToCross0] = outputs.crossTickNode;
            ticks0[cache.nextTickToCross0] = outputs.crossTick;
            ticks0[cache.nextTickToAccum0] = outputs.accumTick;
            //cross otherwise break
            if (cache.nextTickToAccum0 > cache.stopTick0) {
                (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                    tickNodes[cache.nextTickToAccum0],
                    ticks0[cache.nextTickToAccum0].liquidityDelta,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true
                );
                if (cache.nextTickToCross0 == cache.nextTickToAccum0) {
                    revert InfiniteTickLoop0(cache.nextTickToAccum0);
                }
            } else break;
        }
        // pool0 post-loop sync
        {
            /// @dev - place liquidity at stopTick0 for continuation when TWAP moves back down
            if (nextLatestTick > state.latestTick) {
                if (cache.nextTickToAccum0 != cache.stopTick0) {
                    tickNodes[cache.stopTick0] = ICoverPoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0,
                        0, 0
                    );
                    tickNodes[cache.nextTickToAccum0].nextTick = cache.stopTick0;
                    tickNodes[cache.nextTickToCross0].previousTick = cache.stopTick0;
                }
            }
            /// @dev - update amount deltas on stopTick
            ICoverPoolStructs.Tick memory stopTick0 = ticks0[cache.stopTick0];
            ICoverPoolStructs.TickNode memory stopTickNode0 = tickNodes[cache.stopTick0];
            (stopTick0) = _stash(
                stopTick0,
                cache,
                pool0.liquidity,
                true
            );
            if (nextLatestTick < state.latestTick) {
                if (cache.nextTickToAccum0 >= cache.stopTick0) {
                    // cross in and activate next auction
                    (pool0.liquidity, cache.nextTickToCross0, cache.nextTickToAccum0) = _cross(
                        tickNodes[cache.nextTickToAccum0],
                        ticks0[cache.nextTickToAccum0].liquidityDelta,
                        cache.nextTickToCross0,
                        cache.nextTickToAccum0,
                        pool0.liquidity,
                        true
                    );
                }
                if (cache.nextTickToCross0 != nextLatestTick) {
                    stopTickNode0 = ICoverPoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0,
                        state.accumEpoch,
                        pool0.liquidity
                    );
                    tickNodes[cache.nextTickToAccum0].nextTick = nextLatestTick;
                    tickNodes[cache.nextTickToCross0].previousTick = nextLatestTick;
                }
            }
            stopTick0.liquidityDelta += int128(
                stopTickNode0.liquidityDeltaMinus
            );
            stopTickNode0.liquidityDeltaMinus = 0;
            stopTickNode0.accumEpochLast = state.accumEpoch;
            ticks0[cache.stopTick0] = stopTick0;
            tickNodes[cache.stopTick0] = stopTickNode0; 
        }

        // loop over ticks1 until stopTick1
        while (true) {
            // rollover deltas from current auction
            (cache, pool1) = _rollover(cache, pool1, false);
            // accumulate to next tick
            ICoverPoolStructs.AccumulateOutputs memory outputs;
            outputs = _accumulate(
                tickNodes[cache.nextTickToAccum1],
                tickNodes[cache.nextTickToCross1],
                ticks1[cache.nextTickToCross1],
                ticks1[cache.nextTickToAccum1],
                cache.deltas1,
                state.accumEpoch,
                true,
                nextLatestTick > state.latestTick
                    ? cache.nextTickToAccum1 < cache.stopTick1
                    : cache.nextTickToAccum1 > cache.stopTick1
            );
            cache.deltas1 = outputs.deltas;
            tickNodes[cache.nextTickToAccum1] = outputs.accumTickNode;
            tickNodes[cache.nextTickToCross1] = outputs.crossTickNode;
            ticks1[cache.nextTickToCross1] = outputs.crossTick;
            ticks1[cache.nextTickToAccum1] = outputs.accumTick;
            //cross otherwise break
            if (cache.nextTickToAccum1 < cache.stopTick1) {
                (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                    tickNodes[cache.nextTickToAccum1],
                    ticks1[cache.nextTickToAccum1].liquidityDelta,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false
                );
                /// @audit - for testing; remove before production
                if (cache.nextTickToCross1 == cache.nextTickToAccum1)
                    revert InfiniteTickLoop1(cache.nextTickToCross1);
            } else break;
        }
        // post-loop pool1 sync
        {
            /// @dev - place liquidity at stopTick1 for continuation when TWAP moves back up
            if (nextLatestTick < state.latestTick) {
                if (cache.nextTickToAccum1 != cache.stopTick1) {
                    tickNodes[cache.stopTick1] = ICoverPoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        0, 0
                    );
                    tickNodes[cache.nextTickToCross1].nextTick = cache.stopTick1;
                    tickNodes[cache.nextTickToAccum1].previousTick = cache.stopTick1;
                }
            }
            /// @dev - update amount deltas on stopTick
            ICoverPoolStructs.Tick memory stopTick1 = ticks1[cache.stopTick1];
            ICoverPoolStructs.TickNode memory stopTickNode1 = tickNodes[cache.stopTick1];
            (stopTick1) = _stash(
                stopTick1,
                cache,
                pool1.liquidity,
                false
            );
            if (nextLatestTick > state.latestTick) {
                // if this is true we need to insert new latestTick
                if (cache.nextTickToAccum1 != nextLatestTick) {
                    console.log('nextlatesttick check');
                    console.logInt(cache.nextTickToCross1);
                    console.logInt(cache.nextTickToAccum1);
                    stopTickNode1 = ICoverPoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        state.accumEpoch,
                        0
                    );
                    tickNodes[cache.nextTickToCross1].nextTick = nextLatestTick;
                    tickNodes[cache.nextTickToAccum1].previousTick = nextLatestTick;
                }
                //TODO: replace nearestTick with priceLimit for swapping...maybe
                if (cache.nextTickToAccum1 <= cache.stopTick1) {
                    (pool1.liquidity, cache.nextTickToCross1, cache.nextTickToAccum1) = _cross(
                        tickNodes[cache.nextTickToAccum1],
                        ticks1[cache.nextTickToAccum1].liquidityDelta,
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        pool1.liquidity,
                        false
                    );
                }
                pool0.liquidity = 0;
            } else {
                pool1.liquidity = 0;
            }
            stopTick1.liquidityDelta += int128(
                stopTickNode1.liquidityDeltaMinus
            );
            stopTickNode1.liquidityDeltaMinus = 0;
            stopTickNode1.accumEpochLast = state.accumEpoch;
            ticks1[cache.stopTick1] = stopTick1;
            tickNodes[cache.stopTick1] = stopTickNode1;
        }
        // set pool price based on nextLatestTick
        pool0.price = TickMath.getSqrtRatioAtTick(nextLatestTick - state.tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(nextLatestTick + state.tickSpread);
        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.number - state.genesisBlock);
        state.latestTick = nextLatestTick;
        state.latestPrice = TickMath.getSqrtRatioAtTick(nextLatestTick);
        // console.log("-- END ACCUMULATE LAST BLOCK --");
        return (state, pool0, pool1);
    }

    function _rollover(
        ICoverPoolStructs.AccumulateCache memory cache,
        ICoverPoolStructs.PoolState memory pool,
        bool isPool0
    ) internal view returns (
        ICoverPoolStructs.AccumulateCache memory,
        ICoverPoolStructs.PoolState memory
    ) {
        if (pool.liquidity == 0) {
            /// @auditor - deltas should be zeroed out here
            return (cache, pool);
        }
        uint160 crossPrice = TickMath.getSqrtRatioAtTick(
            isPool0 ? cache.nextTickToCross0 : cache.nextTickToCross1
        );
        uint160 accumPrice;
        {
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
        if (isPool0){
            if (!(pool.price > accumPrice && pool.price < crossPrice)) currentPrice = accumPrice;
        } else{
            if (!(pool.price < accumPrice && pool.price > crossPrice)) currentPrice = accumPrice;
        }

        //handle liquidity rollover
        if (isPool0) {
            // amountIn pool did not receive
            uint128 amountInDelta     = uint128(DyDxMath.getDy(pool.liquidity, currentPrice, crossPrice, false));
            uint128 amountInDeltaMax  = uint128(DyDxMath.getDy(pool.liquidity, accumPrice, crossPrice, false));
            amountInDelta      += pool.amountInDelta;
            amountInDeltaMax   -= pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            // amountOut pool has leftover
            uint128 amountOutDelta    = uint128(DyDxMath.getDx(pool.liquidity, currentPrice, crossPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDx(pool.liquidity, accumPrice, crossPrice, false));
            amountOutDeltaMax -= pool.amountOutDeltaMaxClaimed;
            pool.amountOutDeltaMaxClaimed = 0;

            // update cache deltas
            cache.deltas0.amountInDelta += amountInDelta;
            cache.deltas0.amountInDeltaMax += amountInDeltaMax;
            cache.deltas0.amountOutDelta += amountOutDelta;
            cache.deltas0.amountOutDeltaMax += amountOutDeltaMax;
            console.log('rollover deltas check');
            console.log(cache.deltas0.amountInDelta);
            console.log(cache.deltas0.amountOutDelta);
        } else {
            // amountIn pool did not receive
            uint128 amountInDelta = uint128(DyDxMath.getDx(pool.liquidity, crossPrice, currentPrice, false));
            uint128 amountInDeltaMax = uint128(DyDxMath.getDx(pool.liquidity, crossPrice, accumPrice, false));
            amountInDelta      += pool.amountInDelta;
            amountInDeltaMax   -= pool.amountInDeltaMaxClaimed;
            pool.amountInDelta  = 0;
            pool.amountInDeltaMaxClaimed = 0;

            // amountOut pool has leftover
            uint128 amountOutDelta   = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, currentPrice, false));
            uint128 amountOutDeltaMax = uint128(DyDxMath.getDy(pool.liquidity, crossPrice, accumPrice, false));
            amountOutDeltaMax -= pool.amountOutDeltaMaxClaimed;
            pool.amountOutDeltaMaxClaimed = 0;

            // update cache deltas
            cache.deltas1.amountInDelta += amountInDelta;
            cache.deltas1.amountInDeltaMax += amountInDeltaMax;
            cache.deltas1.amountOutDelta += amountOutDelta;
            cache.deltas1.amountOutDeltaMax += amountOutDeltaMax;
        }
        return (cache, pool);
    }

    //TODO: deltas struct so just that can be passed in
    //TODO: accumulate takes Tick and TickNode structs instead of storage pointer
    //TODO: bool stashDeltas might be better to avoid duplicate code
    function _accumulate(
        ICoverPoolStructs.TickNode memory accumTickNode,
        ICoverPoolStructs.TickNode memory crossTickNode,
        ICoverPoolStructs.Tick memory crossTick,
        ICoverPoolStructs.Tick memory accumTick,
        ICoverPoolStructs.Deltas memory deltas,
        uint32 accumEpoch,
        bool removeLiquidity,
        bool updateAccumDeltas
    ) internal view returns (ICoverPoolStructs.AccumulateOutputs memory) {
        
        // update tick epoch
        if (accumTickNode.liquidityDeltaMinus > 0 && updateAccumDeltas) {
            accumTickNode.accumEpochLast = accumEpoch;
        }

        if (crossTick.amountInDeltaMaxStashed > 0) {
            /// @dev - else we migrate carry deltas onto cache
            // add carry amounts to cache
            (crossTick, deltas) = Deltas.unstash(crossTick, deltas);
        }
        if (updateAccumDeltas) {
            // migrate carry deltas from cache to accum tick
            console.log('update accum deltas');
            ICoverPoolStructs.Deltas memory accumDeltas = accumTick.deltas;
            if (accumTick.deltas.amountInDeltaMax > 0) {
                uint256 percentInOnTick = accumDeltas.amountInDeltaMax * 1e38 / (deltas.amountInDeltaMax + accumDeltas.amountInDeltaMax);
                uint256 percentOutOnTick = accumDeltas.amountOutDeltaMax * 1e38 / (deltas.amountOutDeltaMax + accumDeltas.amountOutDeltaMax);
                console.log(percentInOnTick);
                console.log(percentOutOnTick);
                (deltas, accumDeltas) = Deltas.transfer(deltas, accumDeltas, percentInOnTick, percentOutOnTick);
                accumTick.deltas = accumDeltas;
                // update delta maxes
                deltas.amountInDeltaMax -= uint128(uint256(deltas.amountInDeltaMax) * (1e38 - percentInOnTick) / 1e38);
                deltas.amountOutDeltaMax -= uint128(uint256(deltas.amountOutDeltaMax) * (1e38 - percentOutOnTick) / 1e38);
            }
        }

        //remove all liquidity from cross tick
        if (removeLiquidity) {
            crossTick.liquidityDelta += int128(crossTickNode.liquidityDeltaMinus);
            crossTickNode.liquidityDeltaMinus = 0;
        }
        // clear out stash
        crossTick.amountInDeltaMaxStashed  = 0;
        crossTick.amountOutDeltaMaxStashed = 0;

        return
            ICoverPoolStructs.AccumulateOutputs(
                deltas,
                accumTickNode,
                crossTickNode,
                crossTick,
                accumTick
            );
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        ICoverPoolStructs.TickNode memory accumTickNode,
        int128 liquidityDelta,
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint128 currentLiquidity,
        bool zeroForOne
    )
        internal
        pure
        returns (
            uint128,
            int24,
            int24
        )
    {
        nextTickToCross = nextTickToAccum;

        if (liquidityDelta > 0) {
            currentLiquidity += uint128(uint128(liquidityDelta));
        } else {
            currentLiquidity -= uint128(uint128(-liquidityDelta));
        }
        if (zeroForOne) {
            nextTickToAccum = accumTickNode.previousTick;
        } else {
            nextTickToAccum = accumTickNode.nextTick;
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
        // handle amount in delta
        console.log('stashing');
        ICoverPoolStructs.Deltas memory deltas = isPool0 ? cache.deltas0 : cache.deltas1;
        if (deltas.amountInDeltaMax > 0) {
            console.log(cache.deltas0.amountInDeltaMax);
            console.log(stashTick.deltas.amountInDeltaMax);
            (deltas, stashTick.deltas) = Deltas.transfer(deltas, stashTick.deltas, 1e38, 1e38);
            (deltas, stashTick) = Deltas.onto(deltas, stashTick);
            (deltas, stashTick) = Deltas.stash(deltas, stashTick);
        }
        
        return (stashTick);
    }
}
