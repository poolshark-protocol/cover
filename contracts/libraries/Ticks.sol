// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "../interfaces/ICoverPoolStructs.sol";
import "../utils/CoverPoolErrors.sol";
import "./FullPrecisionMath.sol";
import "./DyDxMath.sol";
// import "hardhat/console.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks
{
    //TODO: alphabetize errors
    error NotImplementedYet();
    error InvalidLatestTick();
    error InfiniteTickLoop0(int24);
    error InfiniteTickLoop1(int24);
    error LiquidityOverflow();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOld();
    error WrongTickUpperOld();
    error NoLiquidityToRollover();
    error AmountInDeltaNeutral();
    error AmountOutDeltaNeutral();

    uint256 internal constant Q96  = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Ticks for mapping(int24 => ICoverPoolStructs.Tick);

    function quote(
        bool zeroForOne,
        uint160 priceLimit,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.SwapCache memory cache
    ) external pure returns (ICoverPoolStructs.SwapCache memory, uint256 amountOut) {
        
        if(zeroForOne ? priceLimit >= cache.price : priceLimit <= cache.price || cache.price == 0) return (cache, 0);
        uint256 nextTickPrice = state.latestPrice;
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
                uint256 newPrice = FullPrecisionMath.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input);
                /// @auditor - check tests to see if we need overflow handle
                // if (!(nextTickPrice <= newPrice && newPrice < cache.price)) {
                //     console.log('overflow check');
                //     newPrice = uint160(FullPrecisionMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                // }
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
                    FullPrecisionMath.mulDiv(cache.input, Q96, cache.liquidity);
                // Calculate output of swap
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice);
                cache.price = newPrice;
                cache.input = 0;
            } else {
                // Swap & cross the tick.
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice);
                cache.price = nextPrice;
                cache.input -= maxDy;
            }
        }
        return (cache, amountOut);
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        ICoverPoolStructs.TickNode memory accumTickNode,
        int128 liquidityDelta,
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint128 currentLiquidity,
        bool zeroForOne
    ) internal pure returns (uint128, int24, int24) {
        nextTickToCross = nextTickToAccum;

        if(liquidityDelta > 0) {
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

    //TODO: ALL TICKS NEED TO BE CREATED WITH 
    function insert(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amount,
        bool isPool0
    ) public returns (ICoverPoolStructs.GlobalState memory) {
        /// @auditor - validation of ticks is in Positions.validate
        // load into memory to reduce storage reads/writes
        ICoverPoolStructs.Tick memory tickUpper = ticks[upper];
        ICoverPoolStructs.Tick memory tickLower = ticks[lower];
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();
        if (type(uint128).max - state.liquidityGlobal < amount) revert LiquidityOverflow();
        /// @auditor lower or upper = latestTick -> should not be possible
        /// @auditor - should we check overflow/underflow of lower and upper ticks?
        /// @auditor - we need to be able to deprecate pools if necessary; so not much reason to do overflow/underflow check
        if (tickLower.liquidityDelta != 0 
            || tickLower.liquidityDeltaMinus != 0
            || tickLower.liquidityDeltaMinusInactive != 0
            || lower == TickMath.MIN_TICK
        ) {
            if (isPool0) {
                tickLower.liquidityDelta      -= int128(amount);
                tickLower.liquidityDeltaMinus += amount;
            } else {
                tickLower.liquidityDelta      += int128(amount);
            }
        } else if (lower != TickMath.MIN_TICK) {
            /// @auditor new latestTick being in between lowerOld and lower handled by Positions.validate()
            // insert new tick
            if (isPool0) {
                tickLower = ICoverPoolStructs.Tick(
                    -int128(amount),
                    amount,0,
                    0,0,0,0
                );
            } else {
                tickLower = ICoverPoolStructs.Tick(
                    int128(amount),
                    0,0,
                    0,0,0,0
                );
            }

        }
        if(tickNodes[lower].nextTick == tickNodes[lower].previousTick && lower != TickMath.MIN_TICK) {
            int24 oldNextTick = tickNodes[lowerOld].nextTick;
            if (upper < oldNextTick) { oldNextTick = upper; }
            /// @auditor - don't set previous tick so upper can be initialized
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
        if (tickUpper.liquidityDelta != 0 
            || tickUpper.liquidityDeltaMinus != 0
            || tickUpper.amountInDelta != 0
            || upper == TickMath.MAX_TICK
        ) {
            if (isPool0) {
                tickUpper.liquidityDelta      += int128(amount);
            } else {
                tickUpper.liquidityDelta      -= int128(amount);
                tickUpper.liquidityDeltaMinus += amount;
            }
        } else if (upper != TickMath.MAX_TICK) {
            if (isPool0) {
                tickUpper = ICoverPoolStructs.Tick(
                    int128(amount),
                    0,0,
                    0,0,0,0
                );
            } else {
                tickUpper = ICoverPoolStructs.Tick(
                    -int128(amount),
                    amount,0,
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
        ticks[lower] = tickLower;
        ticks[upper] = tickUpper;
        return state;
    }

    function remove(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        int24 lower,
        int24 upper,
        uint128 amount,
        bool isPool0,
        bool removeLower,
        bool removeUpper
    ) external {
        //TODO: we can only delete is lower != MIN_TICK or latestTick and all values are 0


        // bool deleteLowerTick = false; bool deleteUpperTick = false;

        //TODO: we can only delete is upper != MAX_TICK or latestTick and all values are 0
        //TODO: can be handled by using inactiveLiquidity == 0 and activeLiquidity == 0
        {
            ICoverPoolStructs.Tick memory tickLower = ticks[lower];
            if (removeLower) {
                if (isPool0) {
                    tickLower.liquidityDelta += int128(amount);
                    tickLower.liquidityDeltaMinus -= amount;
                } else {
                    tickLower.liquidityDelta -= int128(amount);
                }     
            } else {
                if (isPool0) {
                    tickLower.liquidityDeltaMinusInactive -= amount;
                }
            }
            /// @dev - do not remove amountDeltas being carried over
            // if tick is empty clear deltas
            // if (tickLower.liquidityDelta == 0 && tickLower.liquidityDeltaMinus == 0 && tickLower.liquidityDeltaMinusInactive == 0) {
            //     tickLower.amountInDelta = 0;
            //     tickLower.amountOutDelta = 0;
            //     tickLower.amountInDeltaCarryPercent = 0;
            //     tickLower.amountOutDeltaCarryPercent = 0;
            //     if (lower != state.latestTick) {
            //         deleteLowerTick = true;
            //     }
            // }
            ticks[lower] = tickLower;
        }

        //TODO: can be handled using inactiveLiquidity and activeLiquidity == 0

        //TODO: we need to know what tick they're claiming from
        //TODO: that is the tick that should have liquidity values modified
        //TODO: keep unchecked block?
        {
            ICoverPoolStructs.Tick memory tickUpper = ticks[upper];
            if (removeUpper) {
                if (isPool0) {
                    tickUpper.liquidityDelta -= int128(amount);
                } else {
                    tickUpper.liquidityDelta += int128(amount);
                    tickUpper.liquidityDeltaMinus -= amount;
                }
            } else {
                if (!isPool0) {
                    tickUpper.liquidityDeltaMinusInactive -= amount;
                }
            }
            /// @dev - do not remove amountDeltas being carried over
            // if tick is empty clear deltas
            // if (tickUpper.liquidityDelta == 0 && tickUpper.liquidityDeltaMinus == 0 && tickUpper.liquidityDeltaMinusInactive == 0) {
            //     tickUpper.amountInDelta = 0;
            //     tickUpper.amountOutDelta = 0;
            //     tickUpper.amountInDeltaCarryPercent = 0;
            //     tickUpper.amountOutDeltaCarryPercent = 0;
            //     if (upper != state.latestTick) {
            //         deleteUpperTick = true;
            //     }
            // }
            ticks[upper] = tickUpper;
        }

        // if (deleteLowerTick) {
        //     // Delete lower tick.
        //     int24 previous = tickNodes[lower].previousTick;
        //     int24 next     = tickNodes[lower].nextTick;
        //     if(next != upper || !deleteUpperTick) {
        //         tickNodes[previous].nextTick = next;
        //         tickNodes[next].previousTick = previous;
        //     } else {
        //         int24 upperNextTick = tickNodes[upper].nextTick;
        //         tickNodes[tickNodes[lower].previousTick].nextTick = upperNextTick;
        //         tickNodes[upperNextTick].previousTick = previous;
        //     }
        // }
        // if (deleteUpperTick) {
        //     // Delete upper tick.
        //     int24 previous = tickNodes[upper].previousTick;
        //     int24 next     = tickNodes[upper].nextTick;

        //     if(previous != lower || !deleteLowerTick) {
        //         tickNodes[previous].nextTick = next;
        //         tickNodes[next].previousTick = previous;
        //     } else {
        //         int24 lowerPrevTick = tickNodes[lower].previousTick;
        //         tickNodes[lowerPrevTick].nextTick = next;
        //         tickNodes[next].previousTick = lowerPrevTick;
        //     }
        // }
        /// @dev - we can never delete ticks due to amount deltas
    }

    //TODO: deltas struct so just that can be passed in
    //TODO: accumulate takes Tick and TickNode structs instead of storage pointer
    function _accumulate(
        ICoverPoolStructs.TickNode memory tickNode, /// tickNodes[nextTickToAccum]
        ICoverPoolStructs.Tick memory crossTick,
        ICoverPoolStructs.Tick memory accumTick,
        uint32 accumEpoch,
        uint128 currentLiquidity,
        uint128 amountInDelta,
        uint128 amountOutDelta,
        bool removeLiquidity,
        bool updateAccumDeltas
    ) internal view returns (
        ICoverPoolStructs.AccumulateOutputs memory
    ) {
        //update tick epoch
        if(updateAccumDeltas) {
            tickNode.accumEpochLast = accumEpoch;
        }
        if(crossTick.amountInDeltaCarryPercent > 0){

            /// @dev - assume amountInDelta is always <= 0
            // uint256 amountInDeltaCarry = uint256(uint88(crossTick.amountInDelta));
            uint128 amountInDeltaCarry = uint128(uint256(crossTick.amountInDeltaCarryPercent)
                                            * uint256(crossTick.amountInDelta) / 1e18);
            crossTick.amountInDelta -= amountInDeltaCarry;
            crossTick.amountInDeltaCarryPercent = 0;
            amountInDelta += amountInDeltaCarry;
            /// @dev - amountOutDelta cannot exist without amountInDelta
            if(crossTick.amountOutDeltaCarryPercent > 0){
                uint128 amountOutDeltaCarry = uint128(uint256(crossTick.amountOutDeltaCarryPercent) 
                                                * uint256(crossTick.amountOutDelta) / 1e18);
                crossTick.amountOutDelta -= uint128(amountOutDeltaCarry);
                crossTick.amountOutDeltaCarryPercent = 0;
                amountOutDelta += amountOutDeltaCarry;   
            }
        }

        if (currentLiquidity > 0) {
            int256 liquidityDeltaPlus = crossTick.liquidityDelta + int128(crossTick.liquidityDeltaMinus);
            if (liquidityDeltaPlus > 0 && currentLiquidity > uint256(liquidityDeltaPlus)) {
                /// @dev - amount deltas get diluted when liquidity is added
                int256 liquidityPercentIncrease = int256(liquidityDeltaPlus * 1e18 / int256(int128(currentLiquidity)));
                amountOutDelta = uint128(uint256(amountOutDelta) * 1e18 / uint256(1e18 + liquidityPercentIncrease));
                amountInDelta = uint128(uint256(amountInDelta) * 1e18 / uint256(1e18 + liquidityPercentIncrease));
            }
            // skip if stopTick
            if(updateAccumDeltas) {
                accumTick.amountInDelta  += amountInDelta;
                accumTick.amountOutDelta += amountOutDelta;
            }
        }

        //remove all liquidity from cross tick
        if (removeLiquidity) {
            crossTick.liquidityDeltaMinusInactive = crossTick.liquidityDeltaMinus;
            crossTick.liquidityDelta = 0;
            crossTick.liquidityDeltaMinus = 0;
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
        ICoverPoolStructs.AccumulateCache calldata cache,
        uint256 currentPrice,
        uint256 currentLiquidity,
        bool isPool0
    ) external view returns (ICoverPoolStructs.AccumulateCache memory) {
        ICoverPoolStructs.AccumulateCache memory accumCache = cache;
        return _rollover(
            accumCache,
            currentPrice,
            currentLiquidity,
            isPool0
        );
    }

    function _rollover(
        ICoverPoolStructs.AccumulateCache memory cache,
        uint256 currentPrice,
        uint256 currentLiquidity,
        bool isPool0
    ) internal view returns (ICoverPoolStructs.AccumulateCache memory) {
        if (currentLiquidity == 0) {
            // zero out deltas
            return (cache);
        }
        uint160 crossPrice = TickMath.getSqrtRatioAtTick(isPool0 ? cache.nextTickToCross0 
                                                                 : cache.nextTickToCross1);
        uint160 accumPrice;
        {
            int24 nextTickToAccum;
            if (isPool0) {
                nextTickToAccum = (cache.nextTickToAccum0 < cache.stopTick0) ? cache.stopTick0 
                                                                             : cache.nextTickToAccum0;
            } else {
                nextTickToAccum = (cache.nextTickToAccum1 > cache.stopTick1) ? cache.stopTick1 
                                                                             : cache.nextTickToAccum1;
            }
            accumPrice = TickMath.getSqrtRatioAtTick(nextTickToAccum);
        }

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
        if (isPool0) {
            cache.amountInDelta0 += uint128(
                                        FullPrecisionMath.mulDiv(
                                            amountInUnfilled,
                                            Q96,
                                            currentLiquidity
                                        )
                                    );
            cache.amountOutDelta0 += uint128(
                                        FullPrecisionMath.mulDiv(
                                            amountOutLeftover,
                                            Q96, 
                                            currentLiquidity
                                        )
                                    );
        } else {
            cache.amountInDelta1 += uint128(
                                        FullPrecisionMath.mulDiv(
                                            amountInUnfilled,
                                            Q96,
                                            currentLiquidity
                                        )
                                    );
            cache.amountOutDelta1 += uint128(
                                        FullPrecisionMath.mulDiv(
                                            amountOutLeftover,
                                            Q96, 
                                            currentLiquidity
                                        )
                                     );
        }
        return (cache);
    }

    function initialize(
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1,
        int24 latestTick,
        uint32 accumEpoch,
        int24 tickSpread 
    ) external {
        /// @dev - assume latestTick is not MIN_TICK or MAX_TICK
        // if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) revert InvalidLatestTick();
        tickNodes[latestTick] = ICoverPoolStructs.TickNode(
            TickMath.MIN_TICK, TickMath.MAX_TICK, accumEpoch
        );
        tickNodes[TickMath.MIN_TICK] = ICoverPoolStructs.TickNode(
            TickMath.MIN_TICK, latestTick, accumEpoch
        );
        tickNodes[TickMath.MAX_TICK] = ICoverPoolStructs.TickNode(
            latestTick, TickMath.MAX_TICK, accumEpoch
        );
        //TODO: the sqrtPrice cannot move more than 1 tickSpacing away
        pool0.price = TickMath.getSqrtRatioAtTick(latestTick - tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(latestTick + tickSpread);
    }

    //TODO: pass in specific tick and update in storage on calling function
    //TODO: amount delta carry percent needs to be adjusted when we add/remove liquidity
    //TODO: only dilute based on the amount that will be carried
    //TODO: everytime we cross a tick we need to adjust amount delta
    //TODO: dilute amountDelta using inactiveLiquidityDeltaMinus + currentLiquidity
    function _stash (
        ICoverPoolStructs.Tick memory stashTick,
        ICoverPoolStructs.AccumulateCache memory cache,
        uint128 currentLiquidity,
        bool isPool0
    ) internal view returns (ICoverPoolStructs.Tick memory) {
        // return since there is nothing to update
        if (currentLiquidity == 0) return stashTick;
        // handle amount in delta
        {   
            uint128 amountInDelta = isPool0 ? cache.amountInDelta0 : cache.amountInDelta1;
            uint128 amountInDeltaCarry = stashTick.amountInDeltaCarryPercent * stashTick.amountInDelta / 1e18;
            uint128 amountInDeltaNew = amountInDelta + stashTick.amountInDelta;

            /// @dev - amountInDelta should never be greater than 0
            if(amountInDelta != 0) {
                if(currentLiquidity == stashTick.liquidityDeltaMinus) {
                    stashTick.amountInDeltaCarryPercent = uint64(uint256(amountInDeltaCarry) * 1e18 
                                                    / amountInDeltaNew);
                } else {
                    // we need to update amountInDelta
                    stashTick.amountInDeltaCarryPercent = uint64(uint256(amountInDelta + amountInDeltaCarry) * 1e18 
                                                    / amountInDeltaNew);
                }
                stashTick.amountInDelta += amountInDelta;
            }
            //if amount delta is zero but liquidity is active...dilute amountInDelta
             
        }
        // handle amount out delta
        {
            uint128 amountOutDelta = isPool0 ? cache.amountOutDelta0 : cache.amountOutDelta1;
            uint128 amountOutDeltaCarry = stashTick.amountOutDeltaCarryPercent * stashTick.amountOutDelta / 1e18;
            uint128 amountOutDeltaNew = stashTick.amountOutDelta + amountOutDelta;
            if (amountOutDelta != 0) {
                if(currentLiquidity == stashTick.liquidityDeltaMinus) {
                    stashTick.amountOutDeltaCarryPercent = uint64(uint256(amountOutDeltaCarry) * 1e18 
                                                    / amountOutDeltaNew);
                }

                else {
                    // we need to update amountOutDelta
                    stashTick.amountOutDeltaCarryPercent = uint64(uint256(amountOutDelta + amountOutDeltaCarry) * 1e18 
                                                    / amountOutDeltaNew);
                }
                stashTick.amountOutDelta += amountOutDelta;
            }
        }
        return stashTick;
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
            stopTick0:  (nextLatestTick > state.latestTick) ? state.latestTick - state.tickSpread : nextLatestTick,
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
                cache = _rollover(
                    cache,
                    pool0.price,
                    pool0.liquidity,
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
                    true,
                    nextLatestTick > state.latestTick ? cache.nextTickToAccum0 < cache.stopTick0 
                                                      : cache.nextTickToAccum0 > cache.stopTick0
                );
                cache.amountInDelta0 = outputs.amountInDelta;
                cache.amountOutDelta0 = outputs.amountOutDelta;
                tickNodes[cache.nextTickToAccum0] = outputs.accumTickNode;
                ticks0[cache.nextTickToCross0] = outputs.crossTick;
                ticks0[cache.nextTickToAccum0] = outputs.accumTick;
            } else {
                cache.amountInDelta0 = 0;
                cache.amountOutDelta0 = 0;
            }
            //cross otherwise break
            // 
            if (cache.nextTickToAccum0 > cache.stopTick0) {
                (
                    pool0.liquidity, 
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0
                ) = _cross(
                    tickNodes[cache.nextTickToAccum0],
                    ticks0[cache.nextTickToAccum0].liquidityDelta,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    pool0.liquidity,
                    true
                );
                if(cache.nextTickToCross0 == cache.nextTickToAccum0){ revert InfiniteTickLoop0(cache.nextTickToAccum0);}
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
                ticks0[cache.stopTick0] = _stash(
                                                    ticks0[cache.stopTick0],
                                                    cache,
                                                    pool0.liquidity,
                                                    true
                                                );
                if (nextLatestTick < state.latestTick) {
                    if(cache.nextTickToAccum0 >= cache.stopTick0) {
                        (
                            pool0.liquidity, 
                            cache.nextTickToCross0,
                            cache.nextTickToAccum0
                        ) = _cross(
                            tickNodes[cache.nextTickToAccum0],
                            ticks0[cache.nextTickToAccum0].liquidityDelta,
                            cache.nextTickToCross0,
                            cache.nextTickToAccum0,
                            pool0.liquidity,
                            true
                        );
                    }
                }
                ticks0[cache.stopTick0].liquidityDeltaMinusInactive = ticks0[cache.stopTick0].liquidityDeltaMinus;
                ticks0[cache.stopTick0].liquidityDelta += int128(ticks0[cache.stopTick0].liquidityDeltaMinus);
                ticks0[cache.stopTick0].liquidityDeltaMinus = 0;
                tickNodes[cache.stopTick0].accumEpochLast = state.accumEpoch;
                break;
            }
        }
        // loop over pool1 cache until stopTick1
        while (true) {
            //rollover if past latestTick and TWAP moves up
            if (pool1.liquidity > 0){
                cache = _rollover(
                    cache,
                    pool1.price,
                    pool1.liquidity,
                    false
                );
                //accumulate to next tick
                ICoverPoolStructs.AccumulateOutputs memory outputs;
                outputs = _accumulate(
                    //TODO: consolidate cache parameter
                    tickNodes[cache.nextTickToAccum1],
                    ticks1[cache.nextTickToCross1],
                    ticks1[cache.nextTickToAccum1],
                    state.accumEpoch,
                    pool1.liquidity,
                    cache.amountInDelta1, /// @dev - amount deltas will be 1 initially
                    cache.amountOutDelta1,
                    true,
                    nextLatestTick > state.latestTick ? cache.nextTickToAccum1 < cache.stopTick1 
                                                      : cache.nextTickToAccum1 > cache.stopTick1
                );
                cache.amountInDelta1 = outputs.amountInDelta;
                cache.amountOutDelta1 = outputs.amountOutDelta;
                tickNodes[cache.nextTickToAccum1] = outputs.accumTickNode;
                ticks1[cache.nextTickToCross1] = outputs.crossTick;
                ticks1[cache.nextTickToAccum1] = outputs.accumTick;
            } else {
                cache.amountInDelta1 = 0;
                cache.amountOutDelta1 = 0;
            }
            //cross otherwise break
            if (cache.nextTickToAccum1 < cache.stopTick1) {
                (
                    pool1.liquidity, 
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1
                ) = _cross(
                    tickNodes[cache.nextTickToAccum1],
                    ticks1[cache.nextTickToAccum1].liquidityDelta,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    pool1.liquidity,
                    false
                );
                /// @audit - for testing; remove before production
                if(cache.nextTickToCross1 == cache.nextTickToAccum1) revert InfiniteTickLoop1(cache.nextTickToCross1);
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
                                                    0
                                                );
                    tickNodes[cache.nextTickToCross1].nextTick = cache.stopTick1;
                    tickNodes[cache.nextTickToAccum1].previousTick = cache.stopTick1;           
                }
            }
            /// @dev - update amount deltas on stopTick
            ///TODO: this is messing up our amount deltas and carry percents
            ticks1[cache.stopTick1] = _stash(
                    ticks1[cache.stopTick1],
                    cache,
                    pool1.liquidity,
                    false
            );
            if (nextLatestTick > state.latestTick) {
                // if this is true we need to insert new latestTick
                if (cache.nextTickToAccum1 != nextLatestTick) {
                    // if this is true we need to delete the old tick
                    //TODO: don't delete old latestTick for now
                    tickNodes[nextLatestTick] = ICoverPoolStructs.TickNode(
                            cache.nextTickToCross1,
                            cache.nextTickToAccum1,
                            state.accumEpoch
                    );
                    tickNodes[cache.nextTickToCross1].nextTick     = nextLatestTick;
                    tickNodes[cache.nextTickToAccum1].previousTick = nextLatestTick;
                }   
                //TODO: replace nearestTick with priceLimit for swapping...maybe
                if(cache.nextTickToAccum1 <= cache.stopTick1) {
                    (
                        pool1.liquidity, 
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1
                    ) = _cross(
                        tickNodes[cache.nextTickToAccum1],
                        ticks1[cache.nextTickToAccum1].liquidityDelta,
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1,
                        pool1.liquidity,
                        false
                    );
                }
                pool0.liquidity = 0;
                pool1.liquidity = pool1.liquidity;
            }
            ticks1[cache.stopTick1].liquidityDeltaMinusInactive = ticks1[cache.stopTick1].liquidityDeltaMinus;
            ticks1[cache.stopTick1].liquidityDelta += int128(ticks1[cache.stopTick1].liquidityDeltaMinus);
            ticks1[cache.stopTick1].liquidityDeltaMinus = 0;
            tickNodes[cache.stopTick1].accumEpochLast = state.accumEpoch;
        }
        //TODO: remove liquidity from all ticks crossed
        //TODO: handle burn when price is between ticks
        //if TWAP moved up
        if (nextLatestTick > state.latestTick) {
            
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
        }
        //TODO: delete old latestTick if possible
        //TODO: nearestTick not necessary - replace with stopPrice to avoid repeated calculation
        pool0.price = TickMath.getSqrtRatioAtTick(nextLatestTick - state.tickSpread);
        pool1.price = TickMath.getSqrtRatioAtTick(nextLatestTick + state.tickSpread);
        state.latestTick = nextLatestTick;
        state.latestPrice = TickMath.getSqrtRatioAtTick(nextLatestTick);
        // console.log("-- END ACCUMULATE LAST BLOCK --");

        return (state, pool0, pool1);
    }
}
