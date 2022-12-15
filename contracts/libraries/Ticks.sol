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
        mapping(int24 => IPoolsharkHedgePoolStructs.TickData) storage tickData,
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
        mapping(int24 => IPoolsharkHedgePoolStructs.TickData) storage tickData,
        uint256 feeGrowthGlobal,
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
                int128 currentLowerLiquidity = ticks[lower].liquidityDelta;
                // console.log('current lower liquidity:', currentLowerLiquidity);
                //TODO: handle lower = latestTick
                if (currentLowerLiquidity != 0 || ticks[lower].liquidityDeltaMinus != 0 || lower == TickMath.MIN_TICK) {
                    // We are adding liquidity to an existing tick.
                    //TODO: ensure amount < type(int128).max()
                    ticks[lower].liquidityDelta = currentLowerLiquidity + int128(amount);
                } else {
                    // We are inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[lowerOld];
                    int24 oldNextTick = old.nextTick;
                    if (upper < oldNextTick) oldNextTick = upper;
                    console.log('tick check');
                    console.logInt(oldNextTick);
                    console.logInt(lowerOld);
                    console.logInt(lower);
                    //TODO: handle new TWAP being in between lowerOld and lower
                    if ((old.liquidityDelta == 0 && old.liquidityDeltaMinus == 0 && lowerOld != TickMath.MIN_TICK && lowerOld != latestTick) 
                         || lowerOld >= lower 
                         || lower >= oldNextTick) {
                        revert WrongTickLowerOrder();
                    }

                    ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                        lowerOld,
                        oldNextTick,
                        int128(amount),
                        0,
                        feeGrowthGlobal,
                        0,
                        0
                    );

                    old.nextTick = lower;
                    ticks[oldNextTick].previousTick = lower;
                }
            }
            // else the liquidity gets added at the next tick above
        }
        {
            if(uint256(TickMath.getSqrtRatioAtTick(upper)) > currentPrice){
                uint128 currentUpperLiquidity = ticks[upper].liquidityDeltaMinus;
                // console.log('current upper liquidity:', currentUpperLiquidity);
                if (currentUpperLiquidity != 0 || ticks[upper].liquidityDelta != 0 || upper == TickMath.MAX_TICK) {
                    // We are adding liquidity to an existing tick.
                    ticks[upper].liquidityDelta -= int128(amount);
                    ticks[upper].liquidityDeltaMinus += amount;
                } else {
                    // Inserting a new tick.
                    IPoolsharkHedgePoolStructs.Tick storage old = ticks[upperOld];
                    int24 oldNextTick = old.nextTick;

                    console.logInt(upperOld);
                    console.logInt(upper);
                    console.logInt(oldNextTick);
                    console.logInt(old.liquidityDelta);

                    //TODO: handle new TWAP being in between upperOld and upper
                    if ((old.liquidityDelta == 0 && old.liquidityDeltaMinus == 0 && upperOld != TickMath.MAX_TICK && upperOld != latestTick) 
                         || upperOld <= upper || upper >= oldNextTick) {
                        revert WrongTickUpperOrder();
                    }

                    if (old.previousTick < lower) upperOld = lower;

                    //TODO: set feeGrowth to 1 initially
                    ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                        upperOld,
                        oldNextTick,
                        -int128(amount),
                        amount,
                        feeGrowthGlobal,
                        0,
                        0
                    );
                    old.previousTick = upper;
                    ticks[oldNextTick].previousTick = upper;
                }
            }
        }

        int24 tickAtPrice = TickMath.getTickAtSqrtRatio(currentPrice);

        // update nearestTick if between TWAP and currentPrice
        if (nearestTick < upper && upper <= tickAtPrice) {
            nearestTick = upper;
        } else if (nearestTick < lower && lower <= tickAtPrice) {
            nearestTick = lower;
        }

        return nearestTick;
    }

    function remove(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickData) storage tickData,
        int24 lower,
        int24 upper,
        uint128 amount,
        int24 nearestTick
    ) external returns (int24) {
        IPoolsharkHedgePoolStructs.Tick storage current = ticks[lower];
        //TODO: delete at end
        bool deleteLowerTick = lower != TickMath.MIN_TICK && current.liquidityDeltaMinus == amount && current.liquidityDelta == -int128(amount);
        if (deleteLowerTick) {
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
                current.liquidityDeltaMinus -= amount;
                current.liquidityDelta += int128(amount);
            }
        }

        current = ticks[upper];

        bool deleteUpperTick = upper != TickMath.MAX_TICK && current.liquidityDeltaMinus == 0 && amount == uint128(current.liquidityDelta);
        if (deleteUpperTick) {
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
                current.liquidityDelta -= int128(amount);
            }
        }

        if (deleteLowerTick) {
            delete ticks[lower];
        }

        if (deleteUpperTick) {
            delete ticks[upper];
        }

        console.log('removed lower liquidity:', amount);
        console.log('removed upper liquidity:', amount);

        return nearestTick;
    }

    function accumulate(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickData) storage tickData,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentLiquidity,
        uint256 feeGrowthGlobal,
        uint24 tickSpacing
    ) external {

        //assume tick index is increasing as we acccumulate
        int256 carryPercent;
        // lower tick
        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
            carryPercent = 1e18;
        } else {
            uint256 liquidityDelta = ticks[currentTick].liquidityDeltaMinus;
            if (liquidityDelta > 0) {
                carryPercent  = int256(liquidityDelta) * 1e18 / int256(currentLiquidity);
                // console.log('carry percent:', carryPercent);
            } else {
                carryPercent = 1e18;
            }
        }
        console.log(ticks[currentTick].feeGrowthGlobalIn);
        console.log(ticks[nextTickToCross].feeGrowthGlobalIn);
        if (currentLiquidity > 0){
            // update fee growth
            ticks[nextTickToCross].feeGrowthGlobalIn = feeGrowthGlobal;

            // handle amount in delta
            int256 amountInDelta = ticks[currentTick].amountInDelta * carryPercent / 1e18;
            if (amountInDelta > 0) {
                ticks[nextTickToCross].amountInDelta += int128(amountInDelta);
                ticks[currentTick].amountInDelta -= int128(amountInDelta);
            }
            // handle amount out delta
            int256 amountOutDelta = ticks[currentTick].amountOutDelta * carryPercent / 1e18;
            if (amountOutDelta > 0) {
                ticks[nextTickToCross].amountOutDelta += int128(amountOutDelta);
                ticks[currentTick].amountOutDelta -= int128(amountOutDelta);
            }
        }
    }

    function rollover(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickData) storage tickData,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentPrice,
        uint256 currentLiquidity
    ) external {
        if (currentLiquidity == 0) { revert NoLiquidityToRollover(); }
        uint160 nextPrice = TickMath.getSqrtRatioAtTick(nextTickToCross);

        if(currentPrice != nextPrice) {
            //handle liquidity rollover
            uint160 priceAtTick = TickMath.getSqrtRatioAtTick(currentTick);
            uint256 dxUnfilled = DyDxMath.getDx(
                currentLiquidity,
                priceAtTick,
                currentPrice,
                false
            );
            uint256 dyLeftover = DyDxMath.getDy(
                currentLiquidity,
                priceAtTick,
                currentPrice,
                false
            );
            //TODO: ensure this will not overflow with 32 bits
            ticks[nextTickToCross].amountInDelta -= int128(uint128(
                                                        FullPrecisionMath.mulDiv(
                                                            dxUnfilled,
                                                            0x1000000000000000000000000, 
                                                            currentLiquidity
                                                        )));
            ticks[nextTickToCross].amountOutDelta += int128(uint128(
                                                        FullPrecisionMath.mulDiv(
                                                            dyLeftover,
                                                            0x1000000000000000000000000, 
                                                            currentLiquidity
                                                        )));
        }
    }
}
