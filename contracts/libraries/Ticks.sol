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
    error WrongTickLowerOld();
    error WrongTickUpperOld();
    error NoLiquidityToRollover();

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Ticks for mapping(int24 => IPoolsharkHedgePoolStructs.Tick);

    function getMaxLiquidity(int24 tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(tickSpacing)));
    }

    function cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
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
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
        int24 currentTick,
        int24 nextTickToCross,
        uint128 currentLiquidity,
        bool zeroForOne
    ) internal view returns (uint128, int24, int24) {
        currentTick = nextTickToCross;
        int128 liquidityDelta = ticks[nextTickToCross].liquidityDelta;
        console.log('cross tick');
        console.logInt(currentTick);
        console.logInt(nextTickToCross);
        console.logInt(liquidityDelta);
        console.log(currentLiquidity);
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
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
        int24 latestTick,
        uint256 feeGrowthGlobalIn,
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amount,
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
        if (((ticks[lower].liquidityDelta != 0 || ticks[lower].liquidityDeltaMinus != 0))
            || lower == latestTick
            || lower == TickMath.MIN_TICK) {
            // tick exists
            //TODO: ensure amount < type(int128).max()
            if (isPool0) {
                ticks[lower].liquidityDelta      -= int128(amount);
                ticks[lower].liquidityDeltaMinus += amount;
            } else {
                ticks[lower].liquidityDelta      += int128(amount);
            }
            if(ticks[lower].feeGrowthGlobalIn == 0) {
                ticks[lower].feeGrowthGlobalIn = feeGrowthGlobalIn;
            } 
        } else {
            // tick does not exist and we must insert
            int24 oldNextTick = tickNodes[lowerOld].nextTick;
            if (upper < oldNextTick) oldNextTick = upper;
            //TODO: handle new TWAP being in between lowerOld and lower
            if ((tickNodes[lowerOld].nextTick == tickNodes[lowerOld].previousTick) 
                    || lowerOld >= lower 
                    || lower >= oldNextTick) {
                console.log('tick check');
                console.logInt(tickNodes[lowerOld].nextTick);
                console.logInt(tickNodes[lowerOld].previousTick);
                revert WrongTickLowerOld();
            }
            if (isPool0) {
                tickNodes[lower] = IPoolsharkHedgePoolStructs.TickNode(
                    lowerOld,
                    oldNextTick
                );
                ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                    -int128(amount),
                    amount,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            } else {
                tickNodes[lower] = IPoolsharkHedgePoolStructs.TickNode(
                    lowerOld,
                    oldNextTick
                );
                ticks[lower] = IPoolsharkHedgePoolStructs.Tick(
                    int128(amount),
                    0,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            }
            tickNodes[lowerOld].nextTick = lower;
            tickNodes[oldNextTick].previousTick = lower;
        }

        if (((ticks[upper].liquidityDelta != 0 || ticks[upper].liquidityDeltaMinus != 0))
            || upper == latestTick
            || upper == TickMath.MAX_TICK) {
            // We are adding liquidity to an existing tick.
            console.log('upper exists');
            console.logInt(tickNodes[upper].nextTick);
            console.logInt(tickNodes[upper].previousTick);
            if (isPool0) {
                ticks[upper].liquidityDelta      += int128(amount);
            } else {
                ticks[upper].liquidityDelta      -= int128(amount);
                ticks[upper].liquidityDeltaMinus += amount;
            }
            if (ticks[upper].feeGrowthGlobalIn == 0) {
                ticks[upper].feeGrowthGlobalIn = feeGrowthGlobalIn;
            }    
        } else {
            // Inserting a new tick.
            int24 oldPrevTick = tickNodes[upperOld].previousTick;
                        console.logInt(oldPrevTick);
            if (lower > oldPrevTick) oldPrevTick = lower;
            console.log('upper new');
            console.logInt(oldPrevTick);
            console.logInt(upperOld);
            console.logInt(upper);
            console.logInt(latestTick);

            console.logInt(tickNodes[upperOld].nextTick);
            console.logInt(tickNodes[upperOld].previousTick);
            console.logInt(ticks[upper].liquidityDelta);
            console.log(ticks[upper].liquidityDeltaMinus);
            //TODO: handle new TWAP being in between upperOld and upper
            /// @dev - if nextTick == previousTick this tick node is uninitialized
            if (tickNodes[upperOld].nextTick == tickNodes[upperOld].previousTick
                    || upperOld <= upper 
                    || upper <= oldPrevTick
                ) {
                revert WrongTickUpperOld();
            }
            //TODO: set feeGrowth to 1 initially
            if (isPool0) {
                tickNodes[upper] = IPoolsharkHedgePoolStructs.TickNode(
                    oldPrevTick,
                    upperOld
                );
                ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                    int128(amount),
                    0,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            } else {
                tickNodes[upper] = IPoolsharkHedgePoolStructs.TickNode(
                    oldPrevTick,
                    upperOld
                );
                ticks[upper] = IPoolsharkHedgePoolStructs.Tick(
                    -int128(amount),
                    amount,
                    feeGrowthGlobalIn,
                    0,
                    0
                );
            }
            tickNodes[oldPrevTick].nextTick = upper;
            tickNodes[upperOld].previousTick = upper;
        }
    }

    function remove(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
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
            console.log('deleting lower tick');
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
        unchecked {
            if (isPool0) {
                ticks[lower].liquidityDelta += int128(amount);
                ticks[lower].liquidityDeltaMinus -= amount;
            } else {
                console.log('modify liquidity delta');
                console.logInt(ticks[lower].liquidityDelta);
                ticks[lower].liquidityDelta -= int128(amount);
                console.logInt(ticks[lower].liquidityDelta);
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
        unchecked {
            if (isPool0) {
                ticks[upper].liquidityDelta -= int128(amount);
            } else {
                ticks[upper].liquidityDelta += int128(amount);
                ticks[upper].liquidityDeltaMinus -= amount;
            }
        }
        /// @dev - we can never delete ticks due to amount deltas

        console.logInt(ticks[lower].liquidityDelta);
        console.log('removed upper liquidity:', amount);
    }

    function _accumulate(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 nextTickToCross,
        int24 nextTickToAccum,
        uint128 currentLiquidity,
        uint256 feeGrowthGlobal,
        int128 amountInDelta,
        int128 amountOutDelta
    ) internal returns (int128, int128) {
        //TODO: take in amount deltas to limit storage reads and writes
        //assume tick index is increasing as we acccumulate
        int128 deltaPercent;
        uint128 liquidityDeltaMinus = ticks[nextTickToAccum].liquidityDeltaMinus;
        if (liquidityDeltaMinus == 0) {
            deltaPercent = 0;
        } else {
            deltaPercent  = int128(liquidityDeltaMinus) * 1e18 / int128(currentLiquidity);
            // console.log('carry percent:', carryPercent);
        }
        console.log(ticks[nextTickToCross].feeGrowthGlobalIn);
        console.log(ticks[nextTickToAccum].feeGrowthGlobalIn);
        //TODO: do we do this even if there is no liquidity?
        if (currentLiquidity > 0){
            // update fee growth
            ticks[nextTickToAccum].feeGrowthGlobalIn = feeGrowthGlobal;
            // handle amount in delta
            int128 amountInDeltaChange = amountInDelta * deltaPercent / 1e18;
            if (amountInDelta > 0) {
                ticks[nextTickToAccum].amountInDelta += amountInDeltaChange;
                amountInDelta -= amountInDeltaChange;
            }
            // handle amount out delta
            //TODO: this works once but not on a second carryover
            //TODO: implement percent carry to be used during accumulateLastBlock
            int128 amountOutDeltaChange = ticks[nextTickToCross].amountOutDelta * deltaPercent / 1e18;
            if (amountOutDelta > 0) {
                ticks[nextTickToAccum].amountOutDelta += amountOutDeltaChange;
                amountOutDelta -= amountOutDeltaChange;
            }
        }
        return (amountInDelta, amountOutDelta);
    }

    function _rollover(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 nextTickToCross,
        uint256 currentPrice,
        uint256 currentLiquidity,
        bool isPool0
    ) internal returns (int128 amountInDelta, int128 amountOutDelta) {
        if (currentLiquidity == 0) { revert NoLiquidityToRollover(); }
        uint160 nextPrice = TickMath.getSqrtRatioAtTick(nextTickToCross);

        if(currentPrice != nextPrice) {
            //handle liquidity rollover
            uint256 amountInUnfilled; uint256 amountOutLeftover;
            if(isPool0) {
                // leftover x provided
                amountOutLeftover = DyDxMath.getDx(
                    currentLiquidity,
                    currentPrice,
                    nextPrice,
                    false
                );
                // unfilled y amount
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
            //TODO: return this value to limit storage reads and writes
            amountInDelta -= int128(uint128(
                                                        FullPrecisionMath.mulDiv(
                                                            amountInUnfilled,
                                                            0x1000000000000000000000000, 
                                                            currentLiquidity
                                                        )
                                            )
                                    );
            amountOutDelta += int128(uint128(
                                                FullPrecisionMath.mulDiv(
                                                    amountOutLeftover,
                                                    0x1000000000000000000000000, 
                                                    currentLiquidity
                                                )
                                            )
                                    );
        }
    }

    function initialize(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
        IPoolsharkHedgePoolStructs.PoolState storage pool0,
        IPoolsharkHedgePoolStructs.PoolState storage pool1,
        int24 latestTick
    ) external {
        if (latestTick != TickMath.MIN_TICK && latestTick != TickMath.MAX_TICK) {
            tickNodes[latestTick] = IPoolsharkHedgePoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
            tickNodes[TickMath.MIN_TICK] = IPoolsharkHedgePoolStructs.TickNode(
                TickMath.MIN_TICK, latestTick
            );
            tickNodes[TickMath.MAX_TICK] = IPoolsharkHedgePoolStructs.TickNode(
                latestTick, TickMath.MAX_TICK
            );
        } else if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) {
            tickNodes[TickMath.MIN_TICK] = IPoolsharkHedgePoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
            tickNodes[TickMath.MAX_TICK] = IPoolsharkHedgePoolStructs.TickNode(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
        }
                //TODO: we might not need nearestTick; always with defined tickSpacing
        pool0.nearestTick = latestTick;
        pool1.nearestTick = TickMath.MIN_TICK;
        //TODO: the sqrtPrice cannot move more than 1 tickSpacing away
        pool0.price = TickMath.getSqrtRatioAtTick(latestTick);
        pool1.price = pool0.price;
    }
    //TODO: do both pool0 AND pool1
    function accumulateLastBlock(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks0,
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks1,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
        IPoolsharkHedgePoolStructs.PoolState memory pool0,
        IPoolsharkHedgePoolStructs.PoolState memory pool1,
        int24 latestTick,
        int24 nextLatestTick,
        int24 tickSpacing
    ) external returns (
        IPoolsharkHedgePoolStructs.PoolState memory, 
        IPoolsharkHedgePoolStructs.PoolState memory,
        int24
    ) {
        console.log("-- START ACCUMULATE LAST BLOCK --");

        // only accumulate if latestTick needs to move
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing)) {
            return (pool0, pool1, latestTick);
        }

        console.log('zero tick previous:');
        console.logInt(tickNodes[0].previousTick);

        IPoolsharkHedgePoolStructs.AccumulateCache memory cache = IPoolsharkHedgePoolStructs.AccumulateCache({
            nextTickToCross0:  tickNodes[pool0.nearestTick].nextTick,
            nextTickToCross1:  pool1.nearestTick,
            nextTickToAccum0:  pool0.nearestTick,
            nextTickToAccum1:  tickNodes[pool1.nearestTick].nextTick,
            stopTick0:  (nextLatestTick > latestTick) ? latestTick : nextLatestTick,
            stopTick1:  (nextLatestTick > latestTick) ? nextLatestTick : latestTick,
            price0:     pool0.price,
            price1:     pool1.price,
            liquidity0: pool0.liquidity,
            liquidity1: pool1.liquidity,
            amountInDelta0:  0,
            amountInDelta1:  0,
            amountOutDelta0: 0,
            amountOutDelta1: 0
        });

        //TODO: handle ticks not crossed into as a result of big TWAP move
        console.log('check cache');
        console.logInt(cache.nextTickToCross1);
        console.logInt(cache.nextTickToAccum1);
        console.logInt(tickNodes[cache.nextTickToCross1].nextTick);
        // handle partial tick fill
        if(pool0.price != TickMath.getSqrtRatioAtTick(cache.nextTickToAccum0)) {
            if(cache.liquidity0 > 0) {
                console.log('rolling over pool0');
                (
                    cache.amountInDelta0,
                    cache.amountOutDelta0
                ) = _rollover(
                    ticks0,
                    cache.nextTickToCross0,
                    cache.price0,
                    cache.liquidity0,
                    true
                );
            }
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
            //TODO: wipe tick data when tick is deleted
        }
        if(pool1.price != TickMath.getSqrtRatioAtTick(cache.nextTickToAccum1)) {
            if(cache.liquidity1 > 0) {
                console.log('rolling over pool1');
                (
                    cache.amountInDelta1,
                    cache.amountOutDelta1
                ) = _rollover(
                    ticks1,
                    cache.nextTickToCross1,
                    cache.price1,
                    cache.liquidity1,
                    false
                );
            }
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
        }
        while (true) {
            //rollover if past latestTick and TWAP moves down
            if (cache.stopTick0 == nextLatestTick 
                && cache.nextTickToAccum0 < latestTick 
                && cache.liquidity0 > 0
            ) {
                (
                    cache.amountInDelta0,
                    cache.amountOutDelta0
                ) = _rollover(
                    ticks0,
                    cache.nextTickToCross0,
                    cache.price0,
                    cache.liquidity0,
                    false
                );
            }
            (
                cache.amountInDelta0,
                cache.amountOutDelta0
            ) = _accumulate(
                ticks0,
                cache.nextTickToCross0,
                cache.nextTickToAccum0,
                cache.liquidity0,
                pool0.feeGrowthGlobalIn,
                cache.amountInDelta0, /// @dev - amount deltas will be 0 initially
                cache.amountOutDelta0
            );
            if (cache.nextTickToAccum0 > cache.stopTick0) {
                (
                    cache.liquidity0, 
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0
                ) = _cross(
                    ticks0,
                    tickNodes,
                    cache.nextTickToCross0,
                    cache.nextTickToAccum0,
                    cache.liquidity0,
                    true
                ); 
            } else {
                if (nextLatestTick > latestTick)
                    ticks0[latestTick].liquidityDelta += int128(uint128(cache.liquidity0) 
                                                        - ticks0[latestTick].liquidityDeltaMinus);
                break;
            }
        }
        while (true) {
            //rollover if past latestTick and TWAP moves up
            if (cache.stopTick1 == nextLatestTick 
                && cache.nextTickToAccum1 > latestTick 
                && cache.liquidity1 > 0
            ) {
                (
                    cache.amountInDelta1,
                    cache.amountOutDelta1
                ) = _rollover(
                    ticks1,
                    cache.nextTickToCross1,
                    cache.price1,
                    cache.liquidity1,
                    false
                );
            }
            //accumulate to next tick
            (
                cache.amountInDelta1,
                cache.amountOutDelta1
            ) = _accumulate(
                ticks1,
                cache.nextTickToCross1,
                cache.nextTickToAccum1,
                cache.liquidity1,
                pool1.feeGrowthGlobalIn,
                cache.amountInDelta1, /// @dev - amount deltas will be 1 initially
                cache.amountOutDelta1
            );
            //cross otherwise break
            if (cache.nextTickToAccum1 < cache.stopTick1) {
                (
                    cache.liquidity1, 
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1
                ) = _cross(
                    ticks1,
                    tickNodes,
                    cache.nextTickToCross1,
                    cache.nextTickToAccum1,
                    cache.liquidity1,
                    true
                ); 
            } else {
                if (nextLatestTick < latestTick)
                    ticks1[latestTick].liquidityDelta += int128(uint128(cache.liquidity1) 
                                                        - ticks1[latestTick].liquidityDeltaMinus);
                break;
            }
        }
        //TODO: remove liquidity from all ticks crossed
        //TODO: handle burn when price is between ticks
        //if TWAP moved up
        if (nextLatestTick > latestTick) {
            // if this is true we need to insert new latestTick
            if (cache.nextTickToAccum1 != nextLatestTick) {
                // if this is true we need to delete the old tick
                //TODO: don't delete old latestTick for now
                tickNodes[nextLatestTick] = IPoolsharkHedgePoolStructs.TickNode(
                        cache.nextTickToCross1,
                        cache.nextTickToAccum1
                );
                tickNodes[cache.nextTickToAccum1].previousTick = nextLatestTick;
                tickNodes[cache.nextTickToCross1].nextTick     = nextLatestTick;
                //TODO: replace nearestTick with priceLimit for swapping...maybe
            }
            pool0.liquidity = 0;
            pool1.liquidity = cache.liquidity1;
            pool0.nearestTick = nextLatestTick;
            pool1.nearestTick = cache.nextTickToCross1;
        // handle TWAP moving down
        } else if (nextLatestTick < latestTick) {
            // save current liquidity and set liquidity to zero
            // if tick doesn't exist currently
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if (cache.nextTickToAccum0 != nextLatestTick) {
                // if this is true we need to delete the old tick
                //TODO: don't delete old latestTick for now
                tickNodes[nextLatestTick] = IPoolsharkHedgePoolStructs.TickNode(
                        cache.nextTickToAccum0,
                        cache.nextTickToCross0
                );
                tickNodes[cache.nextTickToCross0].previousTick = nextLatestTick;
                tickNodes[cache.nextTickToAccum0].nextTick     = nextLatestTick;
                //TODO: replace nearestTick with priceLimit for swapping...maybe
            }
            pool0.liquidity = cache.liquidity0;
            pool1.liquidity = 0;
            pool0.nearestTick = nextLatestTick;
            pool1.nearestTick = cache.nextTickToAccum0;
        }
        //TODO: delete old latestTick if possible

        // console.log('cross last tick touched');
        // console.logInt(cache.tick);
        // console.logInt(tickNodes[cache.tick].nextTick);

        //TODO: handle pool0 AND pool1
        latestTick = nextLatestTick;
        pool0.price = TickMath.getSqrtRatioAtTick(nextLatestTick);
        pool1.price = pool0.price;

        // console.log('max tick previous:');
        // console.logInt(tickNodes[887272].previousTick);
        // console.logInt(tickNodes[887272].nextTick);
        console.log("-- END ACCUMULATE LAST BLOCK --");
        return (pool0, pool1, latestTick);
        //TODO: update liquidity
        // if latestTick didn't change we don't update liquidity
        // if it did we set to current liquidity


        // insert new latest tick
        // console.log('updated tick after insert');
        // console.logInt(ticks[cache.nextTick].previousTick);
        // console.logInt(latestTick);
        // console.logInt(ticks[latestTick].nextTick);
        // console.log('fee growth check:');
        // console.log(ticks[0].feeGrowthGlobalLast);
        // console.log(ticks[20].feeGrowthGlobalLast);
        // console.log(ticks[30].feeGrowthGlobalLast);
        // console.log(ticks[50].feeGrowthGlobalLast);

    }
}
