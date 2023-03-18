// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import './DyDxMath.sol';
import './TwapOracle.sol';
import '../interfaces/IRangePool.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './Deltas.sol';

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
    ) external returns (
        ICoverPoolStructs.GlobalState memory,
        ICoverPoolStructs.PoolState memory,
        ICoverPoolStructs.PoolState memory
    )
    {
        // update last block checked
        if(state.lastBlock == uint32(block.number) - state.genesisBlock) {
            return (state, pool0, pool1);
        }
        state.lastBlock = uint32(block.number) - state.genesisBlock;
        int24 newLatestTick = TwapOracle.calculateAverageTick(state.inputPool, state.twapLength);
        // only accumulate if latestTick needs to move
        if (state.lastBlock - state.auctionStart <= state.auctionLength                     // auction has not ended
            || newLatestTick / (state.tickSpread) == state.latestTick / (state.tickSpread) // latestTick unchanged
        ) {
            return (state, pool0, pool1);
        }

        /// @dev - latestTick can only move in increments of tickSpread
        if (newLatestTick > state.latestTick) {
            newLatestTick = state.latestTick + state.tickSpread;
        } 
        else {
            newLatestTick = state.latestTick - state.tickSpread;
        } 
        state.accumEpoch += 1;

        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            nextTickToCross0: state.latestTick, // above
            nextTickToCross1: state.latestTick, // below
            nextTickToAccum0: tickNodes[state.latestTick].previousTick, // below
            nextTickToAccum1: tickNodes[state.latestTick].nextTick,     // above
            stopTick0: (newLatestTick > state.latestTick) // where we do stop for pool0 sync
                ? state.latestTick - state.tickSpread
                : newLatestTick,
            stopTick1: (newLatestTick > state.latestTick) // where we do stop for pool1 sync
                ? newLatestTick
                : state.latestTick + state.tickSpread,
            deltas0: ICoverPoolStructs.Deltas(0, 0, 0, 0), // deltas for pool0
            deltas1: ICoverPoolStructs.Deltas(0, 0, 0, 0)  // deltas for pool1
        });

        // rollover pool0 deltas
        (cache, pool0) = _rollover(cache, pool0, true);
        // accumulate pool0 deltas
        {
            ICoverPoolStructs.AccumulateOutputs memory outputs;
            outputs = _accumulate(
                tickNodes[cache.nextTickToAccum0],
                tickNodes[cache.nextTickToCross0],
                ticks0[cache.nextTickToCross0],
                ticks0[cache.nextTickToAccum0],
                cache.deltas0,
                state.accumEpoch
            );
            cache.deltas0 = outputs.deltas;
            tickNodes[cache.nextTickToAccum0] = outputs.accumTickNode;
            tickNodes[cache.nextTickToCross0] = outputs.crossTickNode;
            ticks0[cache.nextTickToCross0] = outputs.crossTick;
            ticks0[cache.nextTickToAccum0] = outputs.accumTick;
        }
        // pool0 checkpoint
        {
            if (newLatestTick > state.latestTick) {
                // create stopTick0 if necessary
                if (cache.nextTickToAccum0 != cache.stopTick0) {
                    tickNodes[cache.stopTick0] = ICoverPoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0,
                        0
                    );
                    tickNodes[cache.nextTickToAccum0].nextTick = cache.stopTick0;
                    tickNodes[cache.nextTickToCross0].previousTick = cache.stopTick0;
                }
            }
            ICoverPoolStructs.Tick memory stopTick0 = ticks0[cache.stopTick0];
            ICoverPoolStructs.TickNode memory stopTickNode0 = tickNodes[cache.stopTick0];
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
                        tickNodes[cache.nextTickToAccum0],
                        ticks0[cache.nextTickToAccum0].liquidityDelta,
                        cache.nextTickToCross0,
                        cache.nextTickToAccum0,
                        pool0.liquidity,
                        true
                    );
                }
                if (cache.nextTickToCross0 != newLatestTick) {
                    // create newLatestTick
                    stopTickNode0 = ICoverPoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0,
                        state.accumEpoch
                    );
                    tickNodes[cache.nextTickToAccum0].nextTick = newLatestTick;
                    tickNodes[cache.nextTickToCross0].previousTick = newLatestTick;
                }
            }
            // zero out tick liquidity
            stopTick0.liquidityDelta += int128(
                stopTick0.liquidityDeltaMinus
            );
            stopTick0.liquidityDeltaMinus = 0;
            stopTickNode0.accumEpochLast = state.accumEpoch;
            ticks0[cache.stopTick0] = stopTick0;
            tickNodes[cache.stopTick0] = stopTickNode0; 
        }
        // rollover deltas pool1
        (cache, pool1) = _rollover(cache, pool1, false);
        // accumulate deltas pool1
        {
            ICoverPoolStructs.AccumulateOutputs memory outputs;
            outputs = _accumulate(
                tickNodes[cache.nextTickToAccum1],
                tickNodes[cache.nextTickToCross1],
                ticks1[cache.nextTickToCross1],
                ticks1[cache.nextTickToAccum1],
                cache.deltas1,
                state.accumEpoch
            );
            cache.deltas1 = outputs.deltas;
            tickNodes[cache.nextTickToAccum1] = outputs.accumTickNode;
            tickNodes[cache.nextTickToCross1] = outputs.crossTickNode;
            ticks1[cache.nextTickToCross1] = outputs.crossTick;
            ticks1[cache.nextTickToAccum1] = outputs.accumTick;
        }
        // pool1 checkpoint
        {
            if (newLatestTick < state.latestTick) {
                // create stopTick1 if necessary
                if (cache.nextTickToAccum1 != cache.stopTick1) {
                    tickNodes[cache.stopTick1] = ICoverPoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        0
                    );
                    tickNodes[cache.nextTickToCross1].nextTick = cache.stopTick1;
                    tickNodes[cache.nextTickToAccum1].previousTick = cache.stopTick1;
                }
            }
            ICoverPoolStructs.Tick memory stopTick1 = ticks1[cache.stopTick1];
            ICoverPoolStructs.TickNode memory stopTickNode1 = tickNodes[cache.stopTick1];
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
                    stopTickNode1 = ICoverPoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        state.accumEpoch
                    );
                    tickNodes[cache.nextTickToCross1].nextTick = newLatestTick;
                    tickNodes[cache.nextTickToAccum1].previousTick = newLatestTick;
                }
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
            stopTickNode1.accumEpochLast = state.accumEpoch;
            ticks1[cache.stopTick1] = stopTick1;
            tickNodes[cache.stopTick1] = stopTickNode1;
        }
        // set pool price based on newLatestTick
        pool0.price = TickMath.getSqrtRatioAtTick(newLatestTick - state.tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(newLatestTick + state.tickSpread);

        // set auction start as an offset of the pool genesis block
        state.auctionStart = uint32(block.number - state.genesisBlock);
        state.latestTick = newLatestTick;
        state.latestPrice = TickMath.getSqrtRatioAtTick(newLatestTick);
    
        return (state, pool0, pool1);
    }

    function _rollover(
        ICoverPoolStructs.AccumulateCache memory cache,
        ICoverPoolStructs.PoolState memory pool,
        bool isPool0
    ) internal pure returns (
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
            uint128 amountInDelta;
            uint128 amountInDeltaMax  = uint128(DyDxMath.getDy(pool.liquidity, accumPrice, crossPrice, false));
            amountInDelta      = pool.amountInDelta;
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
            cache.deltas1.amountInDelta += amountInDelta + 1;
            cache.deltas1.amountInDeltaMax += amountInDeltaMax;
            cache.deltas1.amountOutDelta += amountOutDelta - 1;
            cache.deltas1.amountOutDeltaMax += amountOutDeltaMax;
        }
        return (cache, pool);
    }

    function _accumulate(
        ICoverPoolStructs.TickNode memory accumTickNode,
        ICoverPoolStructs.TickNode memory crossTickNode,
        ICoverPoolStructs.Tick memory crossTick,
        ICoverPoolStructs.Tick memory accumTick,
        ICoverPoolStructs.Deltas memory deltas,
        uint32 accumEpoch
    ) internal pure returns (
        ICoverPoolStructs.AccumulateOutputs memory
    ) {
        // update tick epoch
        if (accumTick.liquidityDeltaMinus > 0) {
            accumTickNode.accumEpochLast = accumEpoch;
        }

        if (crossTick.amountInDeltaMaxStashed > 0) {
            /// @dev - else we migrate carry deltas onto cache
            // add carry amounts to cache
            (crossTick, deltas) = Deltas.unstash(crossTick, deltas);
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
    ) internal pure returns (ICoverPoolStructs.Tick memory) {
        // return since there is nothing to update
        if (currentLiquidity == 0) return (stashTick);
        // handle amount in delta
        ICoverPoolStructs.Deltas memory deltas = isPool0 ? cache.deltas0 : cache.deltas1;
        if (deltas.amountInDeltaMax > 0) {
            (deltas, stashTick.deltas) = Deltas.transfer(deltas, stashTick.deltas, 1e38, 1e38);
            (deltas, stashTick) = Deltas.onto(deltas, stashTick);
            (deltas, stashTick) = Deltas.stash(deltas, stashTick);
        }
        return (stashTick);
    }
}
