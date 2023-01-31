// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "../interfaces/ICoverPoolStructs.sol";
import "../utils/CoverPoolErrors.sol";
import "./FullPrecisionMath.sol";
import "./DyDxMath.sol";
import "hardhat/console.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks
{
    error NotImplementedYet();
    error InfiniteTickLoop0();
    error InfiniteTickLoop1();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOld();
    error WrongTickUpperOld();
    error NoLiquidityToRollover();

    uint256 internal constant Q96  = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Ticks for mapping(int24 => ICoverPoolStructs.Tick);

    function getMaxLiquidity(int24 tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(tickSpacing)));
    }

    function quote(
        bool zeroForOne,
        uint160 priceLimit,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.SwapCache memory cache
    ) external view returns (ICoverPoolStructs.SwapCache memory, uint256 amountOut) {
        
        if(zeroForOne ? priceLimit >= cache.price : priceLimit <= cache.price || cache.price == 0) return (cache, 0);
        uint256 nextTickPrice = uint256(TickMath.getSqrtRatioAtTick(state.latestTick));
        uint256 nextPrice = nextTickPrice;

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = uint256(
                    FullPrecisionMath.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input)
                );
                //TODO: test case if price didn't move because so little was swapped
                if (!(nextPrice <= newPrice && newPrice < cache.price)) {
                    newPrice = uint160(FullPrecisionMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                }
                amountOut = DyDxMath.getDy(cache.liquidity, newPrice, cache.price);
                cache.price = newPrice;
                cache.input = 0;
            } else {
                amountOut = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price);
                cache.price = nextPrice;
                cache.input -= maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextTickPrice);
            if (cache.input <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.liquidity);
                // Calculate output of swap
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice);
                cache.price = newPrice;
                cache.input = 0;
            } else {
                // Swap & cross the tick.
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice);
                cache.price = nextTickPrice;
                cache.input -= maxDy;
            }
        }

        return (cache, amountOut);
    }

    function cross(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        int24 currentTick,
        int24 nextTickToCross,
        uint128 currentLiquidity,
        bool zeroForOne
    ) external view returns (uint256, int24, int24) {
        return _cross(
            ticks,
            tickNodes,
            currentTick,
            nextTickToCross,
            currentLiquidity,
            zeroForOne
        );
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        int24 currentTick,
        int24 nextTickToCross,
        uint128 currentLiquidity,
        bool zeroForOne
    ) internal view returns (uint128, int24, int24) {
        currentTick = nextTickToCross;
        int128 liquidityDelta = ticks[nextTickToCross].liquidityDelta;

        if(liquidityDelta > 0) {
            currentLiquidity += uint128(liquidityDelta);
        } else {
            currentLiquidity -= uint128(-liquidityDelta);
        }
        if (zeroForOne) {
            nextTickToCross = tickNodes[nextTickToCross].previousTick;
        } else {
            nextTickToCross = tickNodes[nextTickToCross].nextTick;
        }
        return (currentLiquidity, currentTick, nextTickToCross);
    }

    //TODO: ALL TICKS NEED TO BE CREATED WITH 
    function insert(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint104 amount,
        bool isPool0
    ) public {
        //TODO: doesn't check if upper/lowerOld is greater/less than MAX/MIN_TICK
        if (lower >= upper || lowerOld >= upperOld) {
            revert WrongTickOrder();
        }
        if (TickMath.MIN_TICK > lower) {
            revert WrongTickLowerRange();
        }
        if (upper > TickMath.MAX_TICK) {
            revert WrongTickUpperRange();
        }
        //TODO: merge Tick and TickData -> ticks0 and ticks1
        //TODO: handle lower = latestTick
        if (ticks[lower].liquidityDelta != 0 
            || ticks[lower].liquidityDeltaMinus != 0
            || ticks[lower].amountInDelta != 0
        ) {
            // tick exists
            //TODO: ensure amount < type(int128).max()
            if (isPool0) {
                ticks[lower].liquidityDelta      -= int104(amount);
                ticks[lower].liquidityDeltaMinus += amount;
            } else {
                ticks[lower].liquidityDelta      += int104(amount);
            }
        } else if (lower != TickMath.MIN_TICK) {
            // tick does not exist and we must insert
            //TODO: handle new TWAP being in between lowerOld and lower
            if (isPool0) {
                ticks[lower] = ICoverPoolStructs.Tick(
                    -int104(amount),
                    amount,
                    0,0,0,0
                );
            } else {
                ticks[lower] = ICoverPoolStructs.Tick(
                    int104(amount),
                    0,
                    0,0,0,0
                );
            }

        }
        if(tickNodes[lower].nextTick == tickNodes[lower].previousTick && lower != TickMath.MIN_TICK) {
            int24 oldNextTick = tickNodes[lowerOld].nextTick;
            if (upper < oldNextTick) { oldNextTick = upper; }
            /// @dev - don't set previous tick so upper can be initialized
            else { tickNodes[oldNextTick].previousTick = lower; }

            if (lowerOld >= lower || lower >= oldNextTick) {
                revert WrongTickLowerOld();
            }
            tickNodes[lower] = ICoverPoolStructs.TickNode(
                lowerOld,
                oldNextTick,
                0
            );
            tickNodes[lowerOld].nextTick = lower;
        }
        if (ticks[upper].liquidityDelta != 0 
            || ticks[upper].liquidityDeltaMinus != 0
            || ticks[lower].amountInDelta != 0
        ) {
            // We are adding liquidity to an existing tick.
            if (isPool0) {
                ticks[upper].liquidityDelta      += int104(amount);
            } else {
                ticks[upper].liquidityDelta      -= int104(amount);
                ticks[upper].liquidityDeltaMinus += amount;
            }
        } else if (upper != TickMath.MAX_TICK) {
            if (isPool0) {
                ticks[upper] = ICoverPoolStructs.Tick(
                    int104(amount),
                    0,
                    0,0,0,0
                );
            } else {
                ticks[upper] = ICoverPoolStructs.Tick(
                    -int104(amount),
                    amount,
                    0,0,0,0
                );
            }
        }
        if(tickNodes[upper].nextTick == tickNodes[upper].previousTick && upper != TickMath.MAX_TICK) {
            int24 oldPrevTick = tickNodes[upperOld].previousTick;
            if (lower > oldPrevTick) oldPrevTick = lower;
            //TODO: handle new TWAP being in between upperOld and upper
            /// @dev - if nextTick == previousTick this tick node is uninitialized
            if (tickNodes[upperOld].nextTick == tickNodes[upperOld].previousTick
                    || upperOld <= upper 
                    || upper <= oldPrevTick
                ) {
                revert WrongTickUpperOld();
            }

            tickNodes[upper] = ICoverPoolStructs.TickNode(
                oldPrevTick,
                upperOld,
                0
            );
            tickNodes[oldPrevTick].nextTick = upper;
            tickNodes[upperOld].previousTick = upper;
        }
    }

    function remove(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        int24 lower,
        int24 upper,
        uint104 amount,
        bool isPool0,
        bool removeLower,
        bool removeUpper
    ) external {
        //TODO: we can only delete is lower != MIN_TICK or latestTick and all values are 0
        bool deleteLowerTick = false;
        //TODO: we can only delete is upper != MAX_TICK or latestTick and all values are 0
        bool deleteUpperTick = false;
        if (deleteLowerTick) {
            // Delete lower tick.
            int24 previous = tickNodes[lower].previousTick;
            int24 next     = tickNodes[lower].nextTick;
            if(next != upper || !deleteUpperTick) {
                tickNodes[previous].nextTick = next;
                tickNodes[next].previousTick = previous;
            } else {
                int24 upperNextTick = tickNodes[upper].nextTick;
                tickNodes[tickNodes[lower].previousTick].nextTick = upperNextTick;
                tickNodes[upperNextTick].previousTick = previous;
            }
        }
        if (removeLower) {
            if (isPool0) {
                ticks[lower].liquidityDelta += int104(amount);
                ticks[lower].liquidityDeltaMinus -= amount;
            } else {
                ticks[lower].liquidityDelta -= int104(amount);
            }
        }

        //TODO: could also modify amounts and then check if liquidityDelta and liquidityDeltaMinus are both zero
        if (deleteUpperTick) {
            // Delete upper tick.
            int24 previous = tickNodes[upper].previousTick;
            int24 next     = tickNodes[upper].nextTick;

            if(previous != lower || !deleteLowerTick) {
                tickNodes[previous].nextTick = next;
                tickNodes[next].previousTick = previous;
            } else {
                int24 lowerPrevTick = tickNodes[lower].previousTick;
                tickNodes[lowerPrevTick].nextTick = next;
                tickNodes[next].previousTick = lowerPrevTick;
            }
        }
        //TODO: we need to know what tick they're claiming from
        //TODO: that is the tick that should have liquidity values modified
        //TODO: keep unchecked block?
        if (removeUpper) {
            if (isPool0) {
                ticks[upper].liquidityDelta -= int104(amount);
            } else {
                ticks[upper].liquidityDelta += int104(amount);
                ticks[upper].liquidityDeltaMinus -= amount;
            }
        }
        /// @dev - we can never delete ticks due to amount deltas
    }

    function accumulate(
        ICoverPoolStructs.TickNode calldata tickNode, /// tickNodes[nextTickToAccum]
        ICoverPoolStructs.Tick calldata crossTick,
        ICoverPoolStructs.Tick calldata accumTick,
        uint32 accumEpoch,
        uint128 currentLiquidity,
        int128 amountInDelta,
        int128 amountOutDelta,
        bool removeLiquidity
    ) external pure returns(
        ICoverPoolStructs.AccumulateOutputs memory
    ) {
        return _accumulate(
            tickNode,
            crossTick,
            accumTick,
            accumEpoch,
            currentLiquidity,
            amountInDelta,
            amountOutDelta,
            removeLiquidity
        );
    }

    //TODO: accumulate takes Tick and TickNode structs instead of storage pointer
    function _accumulate(
        ICoverPoolStructs.TickNode memory tickNode, /// tickNodes[nextTickToAccum]
        ICoverPoolStructs.Tick memory crossTick,
        ICoverPoolStructs.Tick memory accumTick,
        uint32 accumEpoch,
        uint128 currentLiquidity,
        int128 amountInDelta,
        int128 amountOutDelta,
        bool removeLiquidity
    ) internal pure returns (
        ICoverPoolStructs.AccumulateOutputs memory
    ) {

        //update fee growth
        tickNode.accumEpochLast = accumEpoch;

        //remove all liquidity from previous tick
        if (removeLiquidity) {
            crossTick.liquidityDelta = 0;
            crossTick.liquidityDeltaMinus = 0;
        }

        //check for deltas to carry
        if(crossTick.amountInDeltaCarryPercent > 0){
            //TODO: will this work with negatives?
            int104 amountInDeltaCarry = int64(crossTick.amountInDeltaCarryPercent) 
                                            * crossTick.amountInDelta / 1e18;
            crossTick.amountInDelta -= int88(amountInDeltaCarry);
            crossTick.amountInDeltaCarryPercent = 0;
            amountInDelta += amountInDeltaCarry;
            /// @dev - amountOutDelta cannot exist without amountInDelta
            if(crossTick.amountOutDeltaCarryPercent > 0){
            //TODO: will this work with negatives?

                int256 amountOutDeltaCarry = int64(crossTick.amountOutDeltaCarryPercent) 
                                                * crossTick.amountOutDelta / 1e18;
                crossTick.amountOutDelta -= int88(amountOutDeltaCarry);
                crossTick.amountOutDeltaCarryPercent = 0;
                amountOutDelta += int128(amountOutDeltaCarry);
            }
        }
        if (currentLiquidity > 0) {
            //write amount deltas and set cache to zero
            uint128 liquidityDeltaMinus = accumTick.liquidityDeltaMinus;
            if (currentLiquidity != liquidityDeltaMinus) {
                //
                accumTick.amountInDelta  += int88(amountInDelta);
                accumTick.amountOutDelta += int88(amountOutDelta);
                int256 liquidityDeltaPlus = accumTick.liquidityDelta + int128(liquidityDeltaMinus);
                if (liquidityDeltaPlus > 0) {
                    /// @dev - amount deltas get diluted when liquidity is added
                    int128 liquidityPercentIncrease = int128(liquidityDeltaPlus * 1e18 / int256(int128(currentLiquidity - liquidityDeltaMinus)));
                    amountOutDelta = amountOutDelta * (1e18 + liquidityPercentIncrease) / 1e18;
                    amountInDelta = amountInDelta * (1e18 + liquidityPercentIncrease) / 1e18;
                }
            } else {
                accumTick.amountInDelta += int88(amountInDelta);
                accumTick.amountOutDelta += int88(amountOutDelta);
                amountInDelta = 0;
                amountOutDelta = 0;
            }
            // update fee growth
        }
        return ICoverPoolStructs.AccumulateOutputs(
            amountInDelta,
            amountOutDelta,
            tickNode, 
            crossTick, 
            accumTick
        );
    }

    function rollover(
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint256 currentPrice,
        uint256 currentLiquidity,
        int128 amountInDelta,
        int128 amountOutDelta,
        bool isPool0
    ) external pure returns (int128, int128) {
        return _rollover(
            nextTickToCross,
            nextTickToAccum,
            currentPrice,
            currentLiquidity,
            amountInDelta,
            amountOutDelta,
            isPool0
        );
    }

    function _rollover(
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint256 currentPrice,
        uint256 currentLiquidity,
        int128 amountInDelta,
        int128 amountOutDelta,
        bool isPool0
    ) internal pure returns (int128, int128) {
        if (currentLiquidity == 0) return (amountInDelta, amountOutDelta);

        uint160 accumPrice = TickMath.getSqrtRatioAtTick(nextTickToAccum);

        /// @dev - early return; nothing to rollover
        if (currentPrice == accumPrice)
            return (amountInDelta, amountOutDelta);

        uint160 crossPrice = TickMath.getSqrtRatioAtTick(nextTickToCross);

        if (isPool0 ? currentPrice > accumPrice 
                    : currentPrice < accumPrice)
        currentPrice = accumPrice;

        //handle liquidity rollover
        uint256 amountInUnfilled; uint256 amountOutLeftover;
        if(isPool0) {
            // leftover x provided
            amountOutLeftover = DyDxMath.getDx(
                currentLiquidity,
                currentPrice,
                crossPrice
            );
            // unfilled y amount
            amountInUnfilled = DyDxMath.getDy(
                currentLiquidity,
                currentPrice,
                crossPrice
            );
        } else {
            amountOutLeftover = DyDxMath.getDy(
                currentLiquidity,
                crossPrice,
                currentPrice
            );
            amountInUnfilled = DyDxMath.getDx(
                currentLiquidity,
                crossPrice,
                currentPrice
            );
        }

        //TODO: ensure this will not overflow with 32 bits
        //TODO: return this value to limit storage reads and writes
        amountInDelta -= int128(uint128(
                                            FullPrecisionMath.mulDiv(
                                                amountInUnfilled,
                                                Q96,
                                                currentLiquidity
                                            )
                                        )
                                );
        amountOutDelta += int128(uint128(
                                            FullPrecisionMath.mulDiv(
                                                amountOutLeftover,
                                                Q96, 
                                                currentLiquidity
                                            )
                                        )
                                );
        return (amountInDelta, amountOutDelta);
    }

    function initialize(
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1,
        int24 latestTick,
        uint32 accumEpoch,
        int24 tickSpread 
    ) external {
        if (latestTick != TickMath.MIN_TICK && latestTick != TickMath.MAX_TICK) {
            tickNodes[latestTick] = ICoverPoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK, accumEpoch
            );
            tickNodes[TickMath.MIN_TICK] = ICoverPoolStructs.TickNode(
                TickMath.MIN_TICK, latestTick, accumEpoch
            );
            tickNodes[TickMath.MAX_TICK] = ICoverPoolStructs.TickNode(
                latestTick, TickMath.MAX_TICK, accumEpoch
            );
        } else if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) {
            tickNodes[TickMath.MIN_TICK] = ICoverPoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK, accumEpoch
            );
            tickNodes[TickMath.MAX_TICK] = ICoverPoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK, accumEpoch
            );
        }
        //TODO: we might not need nearestTick; always with defined tickSpacing
        pool0.nearestTick = latestTick;
        pool1.nearestTick = TickMath.MIN_TICK;
        //TODO: the sqrtPrice cannot move more than 1 tickSpacing away
        pool0.price = TickMath.getSqrtRatioAtTick(latestTick - tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(latestTick + tickSpread);
    }

    //TODO: pass in specific tick and update in storage on calling function
    function _stash (
        ICoverPoolStructs.Tick memory stashTick,
        ICoverPoolStructs.AccumulateCache memory cache,
        uint128 currentLiquidity,
        bool isPool0
    ) internal pure {
        // return since there is nothing to update
        if (currentLiquidity == 0) return;

        // handle amount in delta
        {
            int128 amountInDelta = isPool0 ? cache.amountInDelta0 : cache.amountInDelta1;
            int128 amountInDeltaCarry = int64(stashTick.amountInDeltaCarryPercent) * stashTick.amountInDelta / 1e18;
            int128 newAmountInDelta = stashTick.amountInDelta + amountInDelta;
            if (amountInDelta != 0 && newAmountInDelta != 0) {
                stashTick.amountInDeltaCarryPercent = uint64(uint128((amountInDelta + amountInDeltaCarry) * 1e18 
                                                / (newAmountInDelta)));
                stashTick.amountInDelta += int88(amountInDelta);
            } else if (amountInDelta != 0 && newAmountInDelta == 0) {
                revert NotImplementedYet();
            }
        }

        // handle amount out delta
        {
            int128 amountOutDelta = isPool0 ? cache.amountOutDelta0 : cache.amountOutDelta1;
            int128 amountOutDeltaCarry = int64(stashTick.amountOutDeltaCarryPercent) * stashTick.amountOutDelta / 1e18;
            int128 newAmountOutDelta = stashTick.amountOutDelta + amountOutDelta;
            if (amountOutDelta != 0 && newAmountOutDelta != 0) {
                stashTick.amountOutDeltaCarryPercent = uint64(uint128((amountOutDelta + amountOutDeltaCarry) * 1e18 
                                                        / (newAmountOutDelta)));
                stashTick.amountOutDelta += int88(amountOutDelta);
            } else if (amountOutDelta != 0 && newAmountOutDelta == 0) {
                revert NotImplementedYet();
            }
        }
    }

    //TODO: do both pool0 AND pool1
    function accumulateLastBlock(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks0,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks1,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.PoolState memory pool0,
        ICoverPoolStructs.PoolState memory pool1,
        ICoverPoolStructs.GlobalState memory state,
        int24 nextLatestTick
    ) external returns (
        ICoverPoolStructs.GlobalState memory,
        ICoverPoolStructs.PoolState memory, 
        ICoverPoolStructs.PoolState memory
    ) {


        // only accumulate if latestTick needs to move
        if (nextLatestTick / (state.tickSpread) == state.latestTick / (state.tickSpread)) {
            return (state, pool0, pool1);
        }
        // console.log("-- START ACCUMULATE LAST BLOCK --");
        state.accumEpoch += 1;

        ICoverPoolStructs.AccumulateCache memory cache = ICoverPoolStructs.AccumulateCache({
            nextTickToCross0:  state.latestTick,
            nextTickToCross1:  state.latestTick,
            nextTickToAccum0:  tickNodes[state.latestTick].previousTick, /// create tick if L > 0 and nextLatestTick != latestTick + tickSpread
            nextTickToAccum1:  tickNodes[state.latestTick].nextTick, /// create tick if L > 0 and nextLatestTick != latestTick - tickSpread
            stopTick0:  (nextLatestTick > state.latestTick) ? state.latestTick - state.tickSpread : nextLatestTick - state.tickSpread,
            stopTick1:  (nextLatestTick > state.latestTick) ? nextLatestTick   : state.latestTick + state.tickSpread,
            amountInDelta0:  0,
            amountInDelta1:  0,
            amountOutDelta0: 0,
            amountOutDelta1: 0
        });

        // accum and/or rollover the side which is active
        // 2. rollover and accumulate in the direction the TWAP moves
        //TODO: handle ticks not crossed into as a result of big TWAP move - DONE?
        // handle partial tick fill
        // update liquidity and ticks
        //TODO: do we return here is latestTick has not moved??
        //TODO: wipe tick data when tick is deleted
        while (true) {
            //rollover if past latestTick and TWAP moves down
            if (pool0.liquidity > 0){
                (
                    cache.amountInDelta0,
                    cache.amountOutDelta0
                ) = _rollover(
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.price, //TODO: update price on each iteration
                    pool0.liquidity,
                    cache.amountInDelta0,
                    cache.amountOutDelta0,
                    true
                );
                //accumulate to next tick
                ICoverPoolStructs.AccumulateOutputs memory outputs;
                outputs = _accumulate(
                    tickNodes[cache.nextTickToAccum0],
                    ticks0[cache.nextTickToCross0],
                    ticks0[cache.nextTickToAccum0],
                    state.accumEpoch,
                    pool0.liquidity,
                    cache.amountInDelta0, /// @dev - amount deltas will be 0 initially
                    cache.amountOutDelta0,
                    true
                );
                cache.amountInDelta0 = outputs.amountInDelta;
                cache.amountOutDelta0 = outputs.amountOutDelta;
                tickNodes[cache.nextTickToAccum0] = outputs.accumTickNode;
                ticks1[cache.nextTickToCross0] = outputs.crossTick;
                ticks1[cache.nextTickToAccum0] = outputs.accumTick;
            }
            //cross otherwise break
            // 
            if (cache.nextTickToAccum0 > cache.stopTick0) {
                (
                    pool0.liquidity, 
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0
                ) = _cross(
                    ticks0,
                    tickNodes,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true
                );
                if(cache.nextTickToCross0 == cache.nextTickToAccum0){ revert InfiniteTickLoop0();}
            } else {
                /// @dev - place liquidity at stopTick0 for continuation when TWAP moves back down
                if (nextLatestTick > state.latestTick) {
                    //TODO: test this
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
                /// @dev - update amount deltas on stopTick
                _stash(
                        ticks0[cache.stopTick0],
                        cache,
                        pool0.liquidity,
                        true
                );
                ticks0[cache.stopTick0].liquidityDelta += int104(ticks0[cache.stopTick0].liquidityDeltaMinus);
                ticks0[cache.stopTick0].liquidityDeltaMinus = 0;
                break;
            }
        }
        //TODO: add latestTickSpread to stop rolling over
        while (true) {
            //rollover if past latestTick and TWAP moves up
            if (pool1.liquidity > 0){
                (
                    cache.amountInDelta1,
                    cache.amountOutDelta1
                ) = _rollover(
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.price, //TODO: update price on each iteration
                    pool1.liquidity,
                    cache.amountInDelta1,
                    cache.amountOutDelta1,
                    false
                );
                //accumulate to next tick
                ICoverPoolStructs.AccumulateOutputs memory outputs;
                outputs = _accumulate(
                    tickNodes[cache.nextTickToAccum1],
                    ticks1[cache.nextTickToCross1],
                    ticks1[cache.nextTickToAccum1],
                    state.accumEpoch,
                    pool1.liquidity,
                    cache.amountInDelta1, /// @dev - amount deltas will be 1 initially
                    cache.amountOutDelta1,
                    true
                );
                cache.amountInDelta1 = outputs.amountInDelta;
                cache.amountOutDelta1 = outputs.amountOutDelta;
                tickNodes[cache.nextTickToAccum1] = outputs.accumTickNode;
                ticks1[cache.nextTickToCross1] = outputs.crossTick;
                ticks1[cache.nextTickToAccum1] = outputs.accumTick;
            } 
            //cross otherwise break
            if (cache.nextTickToAccum1 < cache.stopTick1) {
                (
                    pool1.liquidity, 
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1
                ) = _cross(
                    ticks1,
                    tickNodes,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false
                );
                if(cache.nextTickToCross0 == cache.nextTickToAccum0) revert InfiniteTickLoop1();
            } else {
                /// @dev - place liquidity at stopTick1 for continuation when TWAP moves back up
                if (nextLatestTick < state.latestTick) {
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

                /// @dev - update amount deltas on stopTick
                ///TODO: this is messing up our amount deltas and carry percents
                _stash(
                        ticks1[cache.stopTick1],
                        cache,
                        pool1.liquidity,
                        false
                );

                if (nextLatestTick > state.latestTick) {
                    (
                        pool1.liquidity, 
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1
                    ) = _cross(
                        ticks1,
                        tickNodes,
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        pool1.liquidity,
                        false
                    );
                }
                ticks1[cache.stopTick1].liquidityDelta += int104(ticks1[cache.stopTick1].liquidityDeltaMinus);
                ticks1[cache.stopTick1].liquidityDeltaMinus = 0;
                // tickNodes[cache.stopTick1].accumEpochLast = state.accumEpoch;
                //TODO: if tickSpread > tickSpacing, we need to cross until accum tick is nextLatestTick
                break;
            }
        }
        //TODO: remove liquidity from all ticks crossed
        //TODO: handle burn when price is between ticks
        //if TWAP moved up
        if (nextLatestTick > state.latestTick) {
            // if this is true we need to insert new latestTick
            if (cache.nextTickToCross1 != nextLatestTick) {
                // if this is true we need to delete the old tick
                //TODO: don't delete old latestTick for now
                tickNodes[nextLatestTick] = ICoverPoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        state.accumEpoch
                );
                tickNodes[cache.nextTickToCross1].nextTick     = nextLatestTick;
                tickNodes[cache.nextTickToAccum1].previousTick = nextLatestTick;   
                //TODO: replace nearestTick with priceLimit for swapping...maybe
            }
            pool0.liquidity = 0;
            pool1.liquidity = pool1.liquidity;
        // handle TWAP moving down
        } else if (nextLatestTick < state.latestTick) {
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if (cache.nextTickToCross0 != nextLatestTick) {
                // if this is true we need to delete the old tick
                //TODO: don't delete old latestTick for now
                tickNodes[nextLatestTick] = ICoverPoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0,
                        state.accumEpoch
                );
                tickNodes[cache.nextTickToAccum0].nextTick     = nextLatestTick;
                tickNodes[cache.nextTickToCross0].previousTick = nextLatestTick;
                //TODO: replace nearestTick with priceLimit for swapping...maybe
            }
            pool0.liquidity = pool0.liquidity;
            pool1.liquidity = 0;
            //TODO: lastTick instead of nearestTick
            pool0.lastTick  = cache.nextTickToCross0;
            pool1.lastTick  = tickNodes[nextLatestTick].previousTick;
        }
        //TODO: delete old latestTick if possible

        pool0.nearestTick = tickNodes[nextLatestTick].nextTick;
        pool1.nearestTick = tickNodes[nextLatestTick].previousTick;
        pool0.price = TickMath.getSqrtRatioAtTick(nextLatestTick - state.tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(nextLatestTick + state.tickSpread);
        state.latestTick = nextLatestTick;
        // console.log("-- END ACCUMULATE LAST BLOCK --");

        return (state, pool0, pool1);
    }
}
