// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import "./TickMath.sol";
import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../utils/PoolsharkErrors.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks {

    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrongTickUpperOrder();

    function getMaxLiquidity(uint24 _tickSpacing) public pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(_tickSpacing)));
    }

    function cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint160 secondsGrowthGlobal,
        uint256 currentLiquidity,
        uint256 feeGrowthGlobal,
        bool zeroForOne,
        uint24 tickSpacing
    ) internal returns (uint256, int24) {
        ticks[nextTickToCross].secondsGrowthOutside = secondsGrowthGlobal - ticks[nextTickToCross].secondsGrowthOutside;

        if (zeroForOne) {
            // Moving backwards through the linked list.
            // Liquidity cannot overflow due to the MAX_TICK_LIQUIDITY requirement.
            unchecked {
                //if price is decreasing, liquidity is only removed
                // do all the ticks crosses at the first txn of the block
                if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                    currentLiquidity += ticks[nextTickToCross].liquidity0;
                }
                // // liquidity will never be recycled
                // else {
                //     currentLiquidity += ticks[nextTickToCross].liquidity1;
                // }
            }
            ticks[nextTickToCross].feeGrowthGlobal1 = feeGrowthGlobal;
            nextTickToCross = ticks[nextTickToCross].previousTick;
        } else {
            // Moving forwards through the linked list.
            unchecked {
                // liquidity will never be recycled
                // if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                //     currentLiquidity += ticks[nextTickToCross].liquidity;
                // } 
                if ((nextTickToCross / int24(tickSpacing)) % 2 != 0) {
                    currentLiquidity -= ticks[nextTickToCross].liquidity1;
                }
            }
            ticks[nextTickToCross].feeGrowthGlobal0 = feeGrowthGlobal;
            nextTickToCross = ticks[nextTickToCross].nextTick;
        }
        return (currentLiquidity, nextTickToCross);
    }

    function insert(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        uint256 feeGrowthGlobal0,
        uint256 feeGrowthGlobal1,
        uint160 secondsGrowthGlobal,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amount,
        int24 nearestTick,
        uint160 currentPrice
    ) public returns (int24) {
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
            // Stack overflow.
            uint128 currentLowerLiquidity = ticks[lower].liquidity;
            if (currentLowerLiquidity != 0 || lower == TickMath.MIN_TICK) {
                // We are adding liquidity to an existing tick.
                ticks[lower].liquidity = currentLowerLiquidity + amount;
            } else {
                // We are inserting a new tick.
                IPoolsharkHedgePoolStructs.Tick storage old = ticks[lowerOld];
                int24 oldNextTick = old.nextTick;

                if ((old.liquidity == 0 && lowerOld != TickMath.MIN_TICK) || lowerOld >= lower || lower >= oldNextTick){
                    revert WrongTickLowerOrder();
                }

                if (lower <= nearestTick) {
                    ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                        lowerOld,
                        oldNextTick,
                        amount,
                        feeGrowthGlobal0,
                        feeGrowthGlobal1,
                        secondsGrowthGlobal
                    );
                } else {
                    ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                        lowerOld, 
                        oldNextTick, 
                        amount, 
                        0, 
                        0, 
                        0
                    );
                }

                old.nextTick = lower;
                ticks[oldNextTick].previousTick = lower;
            }
        }

        uint128 currentUpperLiquidity = ticks[upper].liquidity;
        if (currentUpperLiquidity != 0 || upper == TickMath.MAX_TICK) {
            // We are adding liquidity to an existing tick.
            ticks[upper].liquidity = currentUpperLiquidity + amount;
        } else {
            // Inserting a new tick.
            IPoolsharkHedgePoolStructs.Tick storage old = ticks[upperOld];
            int24 oldNextTick = old.nextTick;
            
            if ((old.liquidity == 0 || oldNextTick <= upper) || (upperOld >= upper)){
                revert WrongTickUpperOrder();
            }

            if (upper <= nearestTick) {
                ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                    upperOld,
                    oldNextTick,
                    amount,
                    feeGrowthGlobal0,
                    feeGrowthGlobal1,
                    secondsGrowthGlobal
                );
            } else {
                ticks[upper] = IPoolsharkHedgePoolStructs.Tick(upperOld, oldNextTick, amount, 0, 0, 0);
            }
            old.nextTick = upper;
            ticks[oldNextTick].previousTick = upper;
        }

        int24 tickAtPrice = TickMath.getTickAtSqrtRatio(currentPrice);

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
    ) public returns (int24) {
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
