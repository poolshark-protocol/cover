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

    using Ticks for mapping(int24 => IPoolsharkHedgePoolStructs.Tick);

    function getMaxLiquidity(int24 tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(tickSpacing)));
    }

    function cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentLiquidity,
        bool zeroForOne
    ) external view returns (uint256, int24, int24) {
        return _cross(
            ticks,
            currentTick,
            nextTickToCross,
            currentLiquidity,
            zeroForOne
        );
    }

    //maybe call ticks on msg.sender to get tick
    function _cross(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToCross,
        uint256 currentLiquidity,
        bool zeroForOne
    ) internal view returns (uint256, int24, int24) {
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

    function _accumulate(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 currentTick,
        int24 nextTickToAccum,
        uint256 currentLiquidity,
        uint256 feeGrowthGlobal
    ) internal {
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

    function _rollover(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        int24 nextTickToAccum,
        int24 nextTickToCross,
        uint256 currentPrice,
        uint256 currentLiquidity,
        bool isPool0
    ) internal {
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

    function initialize(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        IPoolsharkHedgePoolStructs.PoolState storage pool,
        int24 latestTick,
        bool isPool0
    ) external {
        if (latestTick != TickMath.MIN_TICK && latestTick != TickMath.MAX_TICK) {
            ticks[latestTick] = IPoolsharkHedgePoolStructs.Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
            ticks[TickMath.MIN_TICK] = IPoolsharkHedgePoolStructs.Tick(
                TickMath.MIN_TICK, latestTick,
                0,0,0,0,0
            );
            ticks[TickMath.MAX_TICK] = IPoolsharkHedgePoolStructs.Tick(
                latestTick, TickMath.MAX_TICK,
                0,0,0,0,0
            );
        } else if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) {
            ticks[TickMath.MIN_TICK] = IPoolsharkHedgePoolStructs.Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
            ticks[TickMath.MAX_TICK] = IPoolsharkHedgePoolStructs.Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
        }
                //TODO: we might not need nearestTick; always with defined tickSpacing
        pool.nearestTick = isPool0 ? latestTick : TickMath.MIN_TICK;
        //TODO: the sqrtPrice cannot move more than 1 tickSpacing away
        pool.price = TickMath.getSqrtRatioAtTick(latestTick);
    }

    function accumulateLastBlock(
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        IPoolsharkHedgePoolStructs.PoolState memory pool,
        bool isPool0,
        int24 latestTick,
        int24 nextLatestTick,
        int24 tickSpacing
    ) external {
        console.log("-- START ACCUMULATE LAST BLOCK --");
        
        // get the next price update

        // check for early return
        bool tickFilled = isPool0 ? pool.price == TickMath.getSqrtRatioAtTick(latestTick + tickSpacing)
                                  : pool.price == TickMath.getSqrtRatioAtTick(latestTick - tickSpacing);
        // only accumulate if...
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing) && !tickFilled) {  // latestTick is not filled
            return;
        }

        console.log('zero tick previous:');
        console.logInt(ticks[0].previousTick);

        IPoolsharkHedgePoolStructs.AccumulateCache memory cache = IPoolsharkHedgePoolStructs.AccumulateCache({
            tick:      pool.nearestTick,
            price:     pool.price,
            liquidity: uint256(pool.liquidity),
            nextTickToCross:  0,
            nextTickToAccum:  0,
            feeGrowthGlobalIn: pool.feeGrowthGlobalIn
        });

        cache.nextTickToCross = isPool0 ? ticks[cache.tick].nextTick 
                                        : cache.tick;
        ///TODO: ensure price != priceAtTick(cache.nextTickToAccum)
        cache.nextTickToAccum = isPool0 ? ticks[cache.tick].previousTick 
                                        : ticks[cache.tick].nextTick;
        // handle partial tick fill
        if(!tickFilled) {
            console.log('rolling over');
            _rollover(
                ticks,
                cache.nextTickToCross,
                cache.nextTickToAccum,
                cache.price,
                cache.liquidity,
                isPool0
            );
            _accumulate(
                ticks,
                cache.tick,
                cache.nextTickToAccum,
                cache.liquidity,
                cache.feeGrowthGlobalIn
            );
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
        }

        // if tick is moving up more than one we need to handle deltas
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing)) {
            return;
        } else if (nextLatestTick > latestTick) {
            // cross latestTick if partial fill
            if(!tickFilled){
                (
                    cache.liquidity, 
                    cache.tick,
                    cache.nextTickToCross
                ) = _cross(
                    ticks,
                    cache.tick,
                    cache.nextTickToAccum,
                    cache.liquidity,
                    isPool0
                );
            }

            // iterate to new latest tick
            while (cache.nextTickToAccum < nextLatestTick) {
                // only iterate to the new TWAP and update liquidity
                if(cache.liquidity > 0){
                    _rollover(
                        ticks,
                        cache.tick,
                        cache.nextTickToAccum,
                        cache.price,
                        uint256(cache.liquidity),
                        isPool0
                    );
                }
                _accumulate(
                    ticks,
                    cache.tick,
                    cache.nextTickToAccum,
                    cache.liquidity,
                    cache.feeGrowthGlobalIn
                );
                (
                    cache.liquidity,
                    cache.tick,
                    cache.nextTickToAccum
                ) = _cross(
                    ticks,
                    cache.tick,
                    cache.nextTickToAccum,
                    cache.liquidity,
                    false
                );
            }

            // if this is true we need to insert new latestTick
            if (cache.nextTickToAccum != nextLatestTick) {
                // if this is true we need to delete the old tick
                if (ticks[latestTick].liquidityDelta == 0 && ticks[latestTick].liquidityDeltaMinus == 0 && cache.tick == latestTick) {
                    ticks[nextLatestTick] = IPoolsharkHedgePoolStructs.Tick(
                        ticks[cache.tick].previousTick, 
                        cache.nextTickToAccum,
                        0,0,0,0,0
                    );
                    ticks[ticks[cache.tick].previousTick].nextTick  = nextLatestTick;
                    ticks[cache.nextTickToAccum].previousTick       = nextLatestTick;
                    delete ticks[latestTick];
                } else {
                    ticks[nextLatestTick] = IPoolsharkHedgePoolStructs.Tick(
                        cache.tick, 
                        cache.nextTickToAccum,
                        0,0,0,0,0
                    );
                    ticks[cache.tick].nextTick                = nextLatestTick;
                    ticks[cache.nextTickToAccum].previousTick = nextLatestTick;
                }
                //TODO: replace nearestTick with priceLimit for swapping
                isPool0 ? pool.nearestTick = nextLatestTick : pool.nearestTick = nextLatestTick;
            }
        // handle TWAP moving down
        } else if (nextLatestTick < latestTick) {
            // save current liquidity and set liquidity to zero
            ticks[latestTick].liquidityDelta += int128(uint128(cache.liquidity));
            pool.liquidity = 0;
            cache.nextTickToAccum = ticks[cache.tick].previousTick;
            while (cache.nextTickToAccum > nextLatestTick) {
                (
                    , 
                    cache.tick,
                    cache.nextTickToAccum
                ) = _cross(
                    ticks,
                    cache.tick,
                    cache.nextTickToAccum,
                    0,
                    !isPool0
                );
            }
            console.log('cross to next latest tick:');
            console.logInt(cache.tick);
            console.logInt(cache.nextTickToAccum);
            // if tick doesn't exist currently
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if (ticks[nextLatestTick].previousTick == 0 && ticks[nextLatestTick].nextTick == 0){
                //TODO: can we assume this is always MIN_TICK?
                ticks[nextLatestTick] = IPoolsharkHedgePoolStructs.Tick(
                        cache.nextTickToAccum, 
                        cache.tick,
                        0,0,0,0,0
                );
                ticks[cache.tick].nextTick = nextLatestTick;
                ticks[cache.nextTickToAccum].previousTick = nextLatestTick;
            }
        }

        console.log('cross last tick touched');
        console.logInt(cache.tick);
        console.logInt(ticks[cache.tick].nextTick);

        latestTick = nextLatestTick;
        pool.price = TickMath.getSqrtRatioAtTick(nextLatestTick);

        console.log('max tick previous:');
        console.logInt(ticks[887272].previousTick);
        console.logInt(ticks[887272].nextTick);
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
        console.log("-- END ACCUMULATE LAST BLOCK --");
    }
}
