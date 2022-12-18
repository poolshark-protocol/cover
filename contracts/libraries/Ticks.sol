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
        uint256 currentLiquidity,
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
        uint256 currentLiquidity,
        bool zeroForOne
    ) internal view returns (uint256, int24, int24) {
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
        mapping(int24 => IPoolsharkHedgePoolStructs.Tick) storage ticks,
        mapping(int24 => IPoolsharkHedgePoolStructs.TickNode) storage tickNodes,
        IPoolsharkHedgePoolStructs.PoolState memory pool,
        bool isPool0,
        int24 latestTick,
        int24 nextLatestTick,
        int24 tickSpacing
    ) external returns (IPoolsharkHedgePoolStructs.PoolState memory, int24) {
        console.log("-- START ACCUMULATE LAST BLOCK --");
        
        // get the next price update
        bool tickFilled = isPool0 ? pool.price == TickMath.getSqrtRatioAtTick(latestTick + tickSpacing)
                                  : pool.price == TickMath.getSqrtRatioAtTick(latestTick - tickSpacing);
        // only accumulate if...
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing) && !tickFilled) {  // latestTick is not filled
            return (pool, latestTick);
        }

        console.log('zero tick previous:');
        console.logInt(tickNodes[0].previousTick);

        IPoolsharkHedgePoolStructs.AccumulateCache memory cache = IPoolsharkHedgePoolStructs.AccumulateCache({
            tick:      isPool0 ? pool.nearestTick : tickNodes[pool.nearestTick].nextTick,
            price:     pool.price,
            liquidity: uint256(pool.liquidity),
            nextTickToCross:  0,
            nextTickToAccum:  0,
            feeGrowthGlobalIn: pool.feeGrowthGlobalIn
        });

        cache.nextTickToCross = isPool0 ? tickNodes[cache.tick].nextTick 
                                        : cache.tick;
        ///TODO: ensure price != priceAtTick(cache.nextTickToAccum)
        cache.nextTickToAccum = isPool0 ? tickNodes[cache.tick].previousTick 
                                        : tickNodes[cache.tick].nextTick;

        console.log('check cache');
        console.logInt(cache.tick);
        console.logInt(cache.nextTickToCross);
        console.logInt(cache.nextTickToAccum);
        console.logInt(tickNodes[cache.tick].nextTick);
        // handle partial tick fill
        if(!tickFilled) {
            if(cache.liquidity > 0) {
                console.log('rolling over');
                _rollover(
                    ticks,
                    cache.nextTickToCross,
                    cache.nextTickToAccum,
                    cache.price,
                    cache.liquidity,
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
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
        }

        // if tick is moving up more than one we need to handle deltas
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing)) {
            return (pool, latestTick);
        } else if (nextLatestTick > latestTick) {
            // cross latestTick if partial fill
            if(!tickFilled && cache.liquidity > 0){
                (
                    cache.liquidity, 
                    cache.tick,
                    cache.nextTickToCross
                ) = _cross(
                    ticks,
                    tickNodes,
                    cache.tick,
                    cache.nextTickToAccum,
                    cache.liquidity,
                    isPool0
                );
                console.log('handle unfilled tick');
                console.logInt(cache.nextTickToCross);
                console.logInt(cache.tick);
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
                    tickNodes,
                    cache.tick,
                    cache.nextTickToAccum,
                    cache.liquidity,
                    false
                );
                console.log('nextTickToAccum:');
                console.logInt(cache.nextTickToAccum);
            }

            // if this is true we need to insert new latestTick
            if (cache.nextTickToAccum != nextLatestTick) {
                console.log('delete old tick?');
                console.logInt(cache.nextTickToAccum);
                console.logInt(cache.tick);
                // if this is true we need to delete the old tick
                if (ticks[latestTick].liquidityDelta == 0 && ticks[latestTick].liquidityDeltaMinus == 0 && cache.nextTickToAccum == latestTick) {
                    console.log('yes');
                    tickNodes[nextLatestTick] = IPoolsharkHedgePoolStructs.TickNode(
                        tickNodes[cache.tick].previousTick,
                        cache.nextTickToAccum
                    );
                    tickNodes[tickNodes[cache.tick].previousTick].nextTick  = nextLatestTick;
                    tickNodes[cache.nextTickToAccum].previousTick       = nextLatestTick;
                    delete tickNodes[latestTick];
                } else {
                    console.log('no');
                    tickNodes[nextLatestTick] = IPoolsharkHedgePoolStructs.TickNode(
                        cache.tick, 
                        cache.nextTickToAccum
                    );
                    tickNodes[cache.tick].nextTick                = nextLatestTick;
                    tickNodes[cache.nextTickToAccum].previousTick = nextLatestTick;
                }
                //TODO: replace nearestTick with priceLimit for swapping
                isPool0 ? pool.nearestTick = nextLatestTick : pool.nearestTick = nextLatestTick;
            }
        // handle TWAP moving down
        } else if (nextLatestTick < latestTick) {
            // save current liquidity and set liquidity to zero
            ticks[latestTick].liquidityDelta += int128(uint128(cache.liquidity));
            pool.liquidity = 0;
            cache.nextTickToAccum = tickNodes[cache.tick].previousTick;
            while (cache.nextTickToAccum > nextLatestTick) {
                (
                    , 
                    cache.tick,
                    cache.nextTickToAccum
                ) = _cross(
                    ticks,
                    tickNodes,
                    cache.tick,
                    cache.nextTickToAccum,
                    0,
                    !isPool0
                );
                console.log('crossing to lower ticks');
                console.logInt(cache.nextTickToCross);
                console.logInt(cache.tick);
            }
            console.log('cross to next latest tick:');
            console.logInt(cache.tick);
            console.logInt(tickNodes[cache.tick].nextTick);
            // if tick doesn't exist currently
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if ((tickNodes[nextLatestTick].previousTick == 0 && tickNodes[nextLatestTick].nextTick == 0)){
                //TODO: can we assume this is always MIN_TICK?
                console.log('next latest tick initialized');
                console.logInt(cache.nextTickToAccum);
                console.logInt(cache.tick);
                tickNodes[nextLatestTick] = IPoolsharkHedgePoolStructs.TickNode(
                        cache.nextTickToAccum,
                        cache.tick
                );
                tickNodes[cache.tick].nextTick = nextLatestTick;
                tickNodes[cache.nextTickToAccum].previousTick = nextLatestTick;
            }
            if (ticks[latestTick].liquidityDelta == 0 && ticks[latestTick].liquidityDeltaMinus == 0) {
                // remove old latest tick
                //TODO: decrease storage reads here
                tickNodes[tickNodes[latestTick].nextTick].previousTick = tickNodes[latestTick].previousTick;
                tickNodes[tickNodes[latestTick].previousTick].nextTick = tickNodes[latestTick].nextTick;
                delete tickNodes[latestTick];
            }
        }

        console.log('cross last tick touched');
        console.logInt(cache.tick);
        console.logInt(tickNodes[cache.tick].nextTick);

        //TODO: handle pool0 AND pool1
        latestTick = nextLatestTick;
        pool.price = TickMath.getSqrtRatioAtTick(nextLatestTick);

        console.log('max tick previous:');
        console.logInt(tickNodes[887272].previousTick);
        console.logInt(tickNodes[887272].nextTick);
                console.log("-- END ACCUMULATE LAST BLOCK --");
        return (pool, latestTick);
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
