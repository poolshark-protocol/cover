// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../utils/PoolsharkErrors.sol";
import "hardhat/console.sol";
import "./FullPrecisionMath.sol";

/// @notice Tick management library for ranged liquidity.
library Ticks
{

    error NotImplementedYet();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrongTickUpperOrder();

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

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
                if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                    currentLiquidity -= ticks[nextTickToCross].liquidity;
                } else {
                    currentLiquidity += ticks[nextTickToCross].liquidity;
                }
            }
            ticks[nextTickToCross].feeGrowthGlobal = feeGrowthGlobal;
            currentTick = nextTickToCross;
            nextTickToCross = ticks[nextTickToCross].previousTick;
        } else {
            unchecked {
                if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                    currentLiquidity += ticks[nextTickToCross].liquidity;
                } else {
                    currentLiquidity -= ticks[nextTickToCross].liquidity;
                }
            }
            ticks[nextTickToCross].feeGrowthGlobal = feeGrowthGlobal;
            currentTick = nextTickToCross;
            nextTickToCross = ticks[nextTickToCross].nextTick;
        }
        return (currentLiquidity, currentTick, nextTickToCross);
    }
    //TODO: ALL TICKS NEED TO BE CREATED WITH 
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
        int24 latestTick,
        uint160 currentPrice
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
                console.log('current lower liquidity:', currentLowerLiquidity);
                //TODO: handle lower = latestTick
                if (currentLowerLiquidity != 0 || lower == TickMath.MIN_TICK) {
                    // We are adding liquidity to an existing tick.
                    ticks[lower].liquidity = currentLowerLiquidity + amount;
                } else {
                    // We are inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[lowerOld];
                    int24 oldNextTick = old.nextTick;
                    if (upper < oldNextTick) oldNextTick = upper;

                    //TODO: handle new TWAP being in between lowerOld and lower
                    if ((old.liquidity == 0 && lowerOld != TickMath.MIN_TICK && lowerOld != latestTick) || lowerOld >= lower || lower >= oldNextTick){
                        revert WrongTickLowerOrder();
                    }

                    ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                        lowerOld,
                        oldNextTick,
                        0,
                        amount,
                        feeGrowthGlobal,
                        feeGrowthGlobal,
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
                console.log('current upper liquidity:', currentUpperLiquidity);
                if (currentUpperLiquidity != 0 || upper == TickMath.MAX_TICK) {
                    // We are adding liquidity to an existing tick.
                    ticks[upper].liquidity = currentUpperLiquidity + amount;
                } else {
                    // Inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[upperOld];
                    int24 oldNextTick = old.nextTick;

                    //TODO: handle new TWAP being in between upperOld and upper
                    if ((old.liquidity == 0 && upperOld != TickMath.MAX_TICK) || upperOld <= upper || upper >= oldNextTick){
                        revert WrongTickUpperOrder();
                    }

                    if (old.previousTick < lower) upperOld = lower;

                    //TODO: set feeGrowth to 1 initially
                    ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                        upperOld,
                        oldNextTick,
                        0,
                        amount,
                        feeGrowthGlobal,
                        feeGrowthGlobal,
                        secondsGrowthGlobal
                    );

                    old.previousTick = upper;
                    ticks[oldNextTick].previousTick = upper;
                }
            }
        }
        {
            //handle upper 
        }

        int24 tickAtPrice = TickMath.getTickAtSqrtRatio(currentPrice);

        //TODO: update nearestTick if between TWAP and currentPrice
        if (nearestTick < upper && upper <= tickAtPrice) {
            nearestTick = upper;
        } else if (nearestTick < lower && lower <= tickAtPrice) {
            nearestTick = lower;
        }
        console.log('inserted tick after zero:');
        console.logInt(ticks[0].nextTick);

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
        //TODO: delete at end
        if (lower != TickMath.MIN_TICK && current.liquidity == amount) {
            // Delete lower tick.
            IPoolsharkHedgePoolStructs.Tick storage previous = ticks[current.previousTick];
            IPoolsharkHedgePoolStructs.Tick storage next = ticks[current.nextTick];

            if(current.nextTick != upper) {
                previous.nextTick = current.nextTick;
                next.previousTick = current.previousTick;
            } else {
                int24 upperNextTick = ticks[upper].nextTick;
                previous.nextTick = upperNextTick;
                ticks[upperNextTick].previousTick = current.previousTick;
            }
            
            if (nearestTick == lower) nearestTick = current.previousTick;

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

            if(current.previousTick != lower) {
                previous.nextTick = current.nextTick;
                next.previousTick = current.previousTick;
            } else {
                int24 lowerPrevTick = ticks[lower].previousTick;
                ticks[lowerPrevTick].nextTick = current.nextTick;
                next.previousTick = lowerPrevTick;
            }

            if (nearestTick == upper) nearestTick = current.previousTick;
        } else {
            unchecked {
                current.liquidity -= amount;
            }
        }

        if (lower != TickMath.MIN_TICK && current.liquidity == amount) {
            delete ticks[lower];
        }

        if (upper != TickMath.MAX_TICK && current.liquidity == amount) {
            delete ticks[upper];
        }

        console.log('removed lower liquidity:', ticks[lower].liquidity);
        console.log('removed upper liquidity:', ticks[upper].liquidity);

        return nearestTick;
    }

    function accumulate(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentLiquidity,
        uint24 tickSpacing,
        uint24 swapFee
    ) external returns (uint256, int24, int24, uint128) {

        //assume tick index is increasing as we acccumulate
        uint256 carryPercent;
        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
            //TODO: make sure casting is safe
            carryPercent = 1e18;
            currentLiquidity += ticks[nextTickToCross].liquidity;
        } else {
            if (currentLiquidity > 0) {
                carryPercent  = 1e18 - uint256(ticks[nextTickToCross].liquidity) * 1e18 / uint256(currentLiquidity);
                console.log('carry percent:', carryPercent);
            } else {
                carryPercent = 1e18;
            }
            currentLiquidity -= ticks[nextTickToCross].liquidity;

            //TODO: take fee in tokenIn for direct conversion
        }
        // accumulate amountIn to carryover
        // adding liquidity
        // carry over everything
        uint256 feeGrowthDiff = ticks[currentTick].feeGrowthGlobal - ticks[currentTick].feeGrowthGlobalLast;
        uint256 amountInCarry;
        if (feeGrowthDiff > 0){
            //TODO: rounding up might solve precision issues
            uint256 amountInDiff  = FullPrecisionMath._mulDiv(
                                        feeGrowthDiff,
                                        currentLiquidity,
                                        Q128
                                    ) * 1e6 / swapFee * (1e6 - swapFee) / 1e6;

            // calculate how much to continue carrying over
            console.log(feeGrowthDiff);
            amountInCarry = amountInDiff * carryPercent / 1e18;
            console.log(amountInDiff);
            console.log(amountInCarry);
            //TODO: need to know last time carried over
            //TODO: update fee growth of next tick and current tick
            // update current and next ticks amountIn
            ticks[nextTickToCross].amountIn += uint128(amountInCarry);
            ticks[currentTick].amountIn += uint128(amountInDiff - amountInCarry);
        }

        ticks[nextTickToCross].feeGrowthGlobalLast = ticks[nextTickToCross].feeGrowthGlobal;

        // set return values
        currentTick = nextTickToCross;
        nextTickToCross = ticks[nextTickToCross].nextTick;
        // liquidity delta already handled

        return (uint256(currentLiquidity), currentTick, nextTickToCross, uint128(amountInCarry));
    }
}
