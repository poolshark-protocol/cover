// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../utils/PoolsharkErrors.sol";
import "hardhat/console.sol";
import "./FullPrecisionMath.sol";
import "./DyDxMath.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks
{

    error NotImplementedYet();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrongTickUpperOrder();
    error NoLiquidityToRollover();

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    function getMaxLiquidity(uint24 _tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(_tickSpacing)));
    }

    //maybe call ticks on msg.sender to get tick
    function cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentLiquidity,
        bool zeroForOne
    ) external view returns (uint256, int24, int24) {
        currentTick = nextTickToCross;
        int128 liquidityDelta = ticks[nextTickToCross].liquidityDelta;
        if(liquidityDelta > 0) {
            currentLiquidity += uint128(liquidityDelta);
        } else {
            currentLiquidity -= uint128(-liquidityDelta);
        }
        if (zeroForOne) {
            nextTickToCross = ticks[nextTickToCross].previousTick;
        } else {
            nextTickToCross = ticks[nextTickToCross].nextTick;
        }
        return (currentLiquidity, currentTick, nextTickToCross);
    }
    //TODO: ALL TICKS NEED TO BE CREATED WITH 
    function insert(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        uint256 feeGrowthGlobalIn,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amount,
        int24 latestTick,
        bool isPool0
    ) external {
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
        // Stack overflow.
        // console.log('current lower liquidity:', currentLowerLiquidity);
        //TODO: handle lower = latestTick
        if (ticks[lower].nextTick != ticks[lower].previousTick || lower == TickMath.MIN_TICK) {
            // tick exists
            //TODO: ensure amount < type(int128).max()
            if (isPool0) {
                ticks[lower].liquidityDelta -= int128(amount);
                ticks[lower].liquidityDeltaMinus += amount;
            } else {
                ticks[lower].liquidityDelta += int128(amount);
            }
            if(ticks[lower].feeGrowthGlobalIn == 0) {
                ticks[lower].feeGrowthGlobalIn = feeGrowthGlobalIn;
            } 
        } else {
            // tick does not exist and we must insert
            int24 oldNextTick = ticks[lowerOld].nextTick;
            if (upper < oldNextTick) oldNextTick = upper;
            //TODO: handle new TWAP being in between lowerOld and lower
            if ((ticks[lowerOld].nextTick == ticks[lowerOld].previousTick && lowerOld != TickMath.MIN_TICK && lowerOld != latestTick) 
                    || lowerOld >= lower 
                    || lower >= oldNextTick) {
                revert WrongTickLowerOrder();
            }
            if (isPool0) {
                ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                    lowerOld,
                    oldNextTick,
                    -int128(amount),
                    amount,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            } else {
                ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                    lowerOld,
                    oldNextTick,
                    int128(amount),
                    0,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            }
            ticks[lowerOld].nextTick = lower;
            ticks[oldNextTick].previousTick = lower;
        }
        if (ticks[upper].nextTick != ticks[upper].previousTick  || upper == TickMath.MAX_TICK) {
            // We are adding liquidity to an existing tick.
            if (isPool0) {
                ticks[upper].liquidityDelta   += int128(amount);
            } else {
                ticks[upper].liquidityDelta      -= int128(amount);
                ticks[upper].liquidityDeltaMinus += amount;
            }
            if(ticks[upper].feeGrowthGlobalIn == 0) {
                ticks[upper].feeGrowthGlobalIn = feeGrowthGlobalIn;
            }    
        } else {
            // Inserting a new tick.
            int24 oldNextTick = ticks[upperOld].nextTick;
            console.logInt(upperOld);
            console.logInt(upper);
            console.logInt(oldNextTick);

            //TODO: handle new TWAP being in between upperOld and upper
            if ((ticks[upperOld].nextTick == ticks[upperOld].previousTick && upperOld != TickMath.MAX_TICK && upperOld != latestTick) 
                    || upperOld <= upper 
                    || upper >= oldNextTick
                ) {
                revert WrongTickUpperOrder();
            }
            //TODO: set feeGrowth to 1 initially
            if (isPool0) {
                ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                    upperOld,
                    oldNextTick,
                    int128(amount),
                    0,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            } else {
                ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                    upperOld,
                    oldNextTick,
                    -int128(amount),
                    amount,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            }
            ticks[upperOld].previousTick = upper;
            ticks[oldNextTick].previousTick = upper;
        }
    }

    function remove(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 lower,
        int24 upper,
        uint128 amount,
        int24 latestTick,
        bool isPool0
    ) external {
        bool deleteLowerTick = lower != TickMath.MIN_TICK && lower != latestTick
                               && (
                                    isPool0 ?
                                      ticks[lower].liquidityDelta == -int128(amount)
                                   && ticks[lower].liquidityDeltaMinus == amount
                                    : ticks[lower].liquidityDelta == int128(amount)
                                   && ticks[lower].liquidityDeltaMinus == 0
                                  )
                                && ticks[lower].amountInDelta  == 0
                                && ticks[lower].amountOutDelta == 0;
        bool deleteUpperTick = upper != TickMath.MAX_TICK && upper != latestTick
                               && (
                                    isPool0 ?
                                      ticks[upper].liquidityDelta == int128(amount)
                                   && ticks[upper].liquidityDeltaMinus == 0
                                    : ticks[upper].liquidityDelta == -int128(amount) 
                                   && ticks[upper].liquidityDeltaMinus == amount
                                  )
                                && ticks[upper].amountInDelta  == 0
                                && ticks[upper].amountOutDelta == 0;
        if (deleteLowerTick) {
            // Delete lower tick.
            int24 previous = ticks[lower].previousTick;
            int24 next     = ticks[lower].nextTick;
            if(next != upper || !deleteUpperTick) {
                ticks[previous].nextTick = next;
                ticks[next].previousTick = previous;
            } else {
                int24 upperNextTick = ticks[upper].nextTick;
                ticks[ticks[lower].previousTick].nextTick = upperNextTick;
                ticks[upperNextTick].previousTick = previous;
            }
        }
        unchecked {
            if (isPool0) {
                ticks[lower].liquidityDelta += int128(amount);
                ticks[lower].liquidityDeltaMinus -= amount;
            } else {
                ticks[lower].liquidityDelta -= int128(amount);
            }
        }

        //TODO: could also modify amounts and then check if liquidityDelta and liquidityDeltaMinus are both zero
        if (deleteUpperTick) {
            // Delete upper tick.
            int24 previous = ticks[upper].previousTick;
            int24 next     = ticks[upper].nextTick;

            if(previous != lower || !deleteLowerTick) {
                ticks[previous].nextTick = next;
                ticks[next].previousTick = previous;
            } else {
                int24 lowerPrevTick = ticks[lower].previousTick;
                ticks[lowerPrevTick].nextTick = next;
                ticks[next].previousTick = lowerPrevTick;
            }
        }
        unchecked {
            if (isPool0) {
                ticks[lower].liquidityDelta -= int128(amount);
            } else {
                ticks[lower].liquidityDelta += int128(amount);
                ticks[lower].liquidityDeltaMinus -= amount;
            }
        }
        /// @dev - we can never delete ticks due to amount deltas

        console.log('removed lower liquidity:', amount);
        console.log('removed upper liquidity:', amount);
    }

    function accumulate(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToAccum,
        uint256 currentLiquidity,
        uint256 feeGrowthGlobal,
        uint24 tickSpacing
    ) external {
        //assume tick index is increasing as we acccumulate
        int256 carryPercent;
        uint256 liquidityDeltaMinus = ticks[currentTick].liquidityDeltaMinus;
        if (liquidityDeltaMinus == 0) {
            carryPercent = 1e18;
        } else {
            carryPercent  = int256(liquidityDeltaMinus) * 1e18 / int256(currentLiquidity);
            // console.log('carry percent:', carryPercent);
        }
        console.log(ticks[currentTick].feeGrowthGlobalIn);
        console.log(ticks[nextTickToAccum].feeGrowthGlobalIn);
        if (currentLiquidity > 0){
            // update fee growth
            ticks[nextTickToAccum].feeGrowthGlobalIn = feeGrowthGlobal;

            // handle amount in delta
            int256 amountInDelta = ticks[currentTick].amountInDelta * carryPercent / 1e18;
            if (amountInDelta > 0) {
                ticks[nextTickToAccum].amountInDelta += int128(amountInDelta);
                ticks[currentTick].amountInDelta     -= int128(amountInDelta);
            }
            // handle amount out delta
            int256 amountOutDelta = ticks[currentTick].amountOutDelta * carryPercent / 1e18;
            if (amountOutDelta > 0) {
                ticks[nextTickToAccum].amountOutDelta += int128(amountOutDelta);
                ticks[currentTick].amountOutDelta     -= int128(amountOutDelta);
            }
        }
    }

    function rollover(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 nextTickToAccum,
        int24 nextTickToCross,
        uint256 currentPrice,
        uint256 currentLiquidity,
        bool isPool0
    ) external {
        if (currentLiquidity == 0) { revert NoLiquidityToRollover(); }
        uint160 nextPrice = TickMath.getSqrtRatioAtTick(nextTickToCross);

        if(currentPrice != nextPrice) {
            //handle liquidity rollover
            uint256 amountInUnfilled; uint256 amountOutLeftover;
            if(isPool0) {
                // leftover liquidity provided
                amountOutLeftover = DyDxMath.getDx(
                    currentLiquidity,
                    currentPrice,
                    nextPrice,
                    false
                );
                // unfilled amount for lp
                amountInUnfilled = DyDxMath.getDy(
                    currentLiquidity,
                    currentPrice,
                    nextPrice,
                    false
                );
            } else {
                amountOutLeftover = DyDxMath.getDy(
                    currentLiquidity,
                    nextPrice,
                    currentPrice,
                    false
                );
                amountInUnfilled = DyDxMath.getDx(
                    currentLiquidity,
                    nextPrice,
                    currentPrice,
                    false
                );
            }

            //TODO: ensure this will not overflow with 32 bits
            ticks[nextTickToAccum].amountInDelta -= int128(uint128(
                                                        FullPrecisionMath.mulDiv(
                                                            amountInUnfilled,
                                                            0x1000000000000000000000000, 
                                                            currentLiquidity
                                                        )));
            ticks[nextTickToAccum].amountOutDelta += int128(uint128(
                                                        FullPrecisionMath.mulDiv(
                                                            amountOutLeftover,
                                                            0x1000000000000000000000000, 
                                                            currentLiquidity
                                                        )));
        }
    }
}
