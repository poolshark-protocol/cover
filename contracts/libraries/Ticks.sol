// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../utils/PoolsharkErrors.sol";
import "hardhat/console.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks
{

    error NotImplementedYet();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrongTickUpperOrder();

    function getMaxLiquidity(uint24 _tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(_tickSpacing)));
    }

    //maybe call ticks on msg.sender to get tick
    function cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint160 secondsGrowthGlobal,
        uint256 currentLiquidity,
        uint256 feeGrowthGlobal,
        bool zeroForOne,
        uint24 tickSpacing
    ) external returns (uint256, int24, int24) {
        ticks[nextTickToCross].secondsGrowthOutside = secondsGrowthGlobal - ticks[nextTickToCross].secondsGrowthOutside;

        if (zeroForOne) {
            // Moving backwards through the linked list.
            // Liquidity cannot overflow due to the TickMath.MAX_TICK_LIQUIDITY requirement.
            unchecked {
                //if price is decreasing, liquidity is only removed
                // do all the ticks crosses at the first txn of the block
                if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                    currentLiquidity -= ticks[nextTickToCross].liquidity;
                }
                // // liquidity will never be recycled
                // else {
                //     currentLiquidity += ticks[nextTickToCross].liquidity;
                // }
            }
            ticks[nextTickToCross].feeGrowthGlobal = feeGrowthGlobal;
            currentTick = nextTickToCross;
            nextTickToCross = ticks[nextTickToCross].previousTick;
        } else {
            revert NotImplementedYet();
        }
        return (currentLiquidity, currentTick, nextTickToCross);
    }

    function insert(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        uint256 feeGrowthGlobal,
        uint160 secondsGrowthGlobal,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amount,
        int24 nearestTick,
        uint160 currentPrice,
        int24 tickAtPrice
    ) external returns (int24) {
        if (lower >= upper || lowerOld >= upperOld) {
            revert WrongTickOrder();
        }
        if (TickMath.MIN_TICK > lower) {
            revert WrongTickLowerRange();
        }
        if (upper > TickMath.MAX_TICK) {
            revert WrongTickUpperRange();
        }
        {
            //TODO: only insert tick if greater than current TWAP
            //TODO: if tick is lower than latestTick adjust the liquidity when the current tick is crossed
            if (uint256(TickMath.getSqrtRatioAtTick(lower)) > currentPrice) {
                    // Stack overflow.
                uint128 currentLowerLiquidity = ticks[lower].liquidity;
                if (currentLowerLiquidity != 0 || lower == TickMath.MIN_TICK) {
                    // We are adding liquidity to an existing tick.
                    ticks[lower].liquidity = currentLowerLiquidity + amount;
                } else {
                    // We are inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[lowerOld];
                    int24 oldNextTick = old.nextTick;
                    if (upper < oldNextTick) oldNextTick = upper;

                    if ((old.liquidity == 0 && lowerOld != TickMath.MIN_TICK) || lowerOld >= lower || lower >= oldNextTick){
                        revert WrongTickLowerOrder();
                    }

                    ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                        lowerOld,
                        oldNextTick,
                        0,0,
                        0,0,
                        amount,
                        feeGrowthGlobal,
                        0,
                        secondsGrowthGlobal
                    );

                    old.nextTick = lower;
                    ticks[oldNextTick].previousTick = lower;
                }
            }
            // else the liquidity gets added at the next tick above
        }
        {
            if(uint256(TickMath.getSqrtRatioAtTick(upper)) > currentPrice){
                uint128 currentUpperLiquidity = ticks[upper].liquidity;
                if (currentUpperLiquidity != 0 || upper == TickMath.MAX_TICK) {
                    // We are adding liquidity to an existing tick.
                    ticks[upper].liquidity = currentUpperLiquidity + amount;
                } else {
                    // Inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[upperOld];
                    int24 oldNextTick = old.nextTick;
                    
                    if ((old.liquidity == 0 && upperOld != TickMath.MAX_TICK) || upperOld <= upper || upper >= oldNextTick){
                        revert WrongTickUpperOrder();
                    }

                    if (old.previousTick < lower) upperOld = lower;

                    ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                        upperOld,
                        oldNextTick,
                        0,0,
                        0,0,
                        amount,
                        feeGrowthGlobal,
                        0,
                        secondsGrowthGlobal
                    );

                    old.nextTick = upper;
                    ticks[oldNextTick].previousTick = upper;
                }
            }
        }
        {
            //handle upper 
        }

        //TODO: update nearestTick if between TWAP and currentPrice
        if (nearestTick < upper && upper <= tickAtPrice) {
            nearestTick = upper;
        } else if (nearestTick < lower && lower <= tickAtPrice) {
            nearestTick = lower;
        }

        return nearestTick;
    }

    function remove(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 lower,
        int24 upper,
        uint128 amount,
        int24 nearestTick
    ) external returns (int24) {
        IPoolsharkHedgePoolStructs.Tick storage current = ticks[lower];

        if (lower != TickMath.MIN_TICK && current.liquidity == amount) {
            // Delete lower tick.
            IPoolsharkHedgePoolStructs.Tick storage previous = ticks[current.previousTick];
            IPoolsharkHedgePoolStructs.Tick storage next = ticks[current.nextTick];

            previous.nextTick = current.nextTick;
            next.previousTick = current.previousTick;

            if (nearestTick == lower) nearestTick = current.previousTick;

            delete ticks[lower];
        } else {
            unchecked {
                current.liquidity -= amount;
            }
        }

        current = ticks[upper];

        if (upper != TickMath.MAX_TICK && current.liquidity == amount) {
            // Delete upper tick.
            IPoolsharkHedgePoolStructs.Tick storage previous = ticks[current.previousTick];
            IPoolsharkHedgePoolStructs.Tick storage next = ticks[current.nextTick];

            previous.nextTick = current.nextTick;
            next.previousTick = current.previousTick;

            if (nearestTick == upper) nearestTick = current.previousTick;

            delete ticks[upper];
        } else {
            unchecked {
                current.liquidity -= amount;
            }
        }

        return nearestTick;
    }
}
