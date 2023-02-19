// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import '../interfaces/ICoverPoolStructs.sol';
import '../utils/CoverPoolErrors.sol';
import './FullPrecisionMath.sol';
import './DyDxMath.sol';
import './TwapOracle.sol';
import 'hardhat/console.sol';

/// @notice Tick management library for ranged liquidity.
library Ticks {
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

    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Ticks for mapping(int24 => ICoverPoolStructs.Tick);

    function quote(
        bool zeroForOne,
        uint160 priceLimit,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.SwapCache memory cache
    ) external view returns (ICoverPoolStructs.SwapCache memory, uint256 amountOut) {
        if (zeroForOne ? priceLimit >= cache.price : priceLimit <= cache.price || cache.price == 0 || cache.input == 0)
            return (cache, 0);
        uint256 nextTickPrice = state.latestPrice;
        uint256 nextPrice = nextTickPrice;

        // determine input boost from tick auction
        cache.auctionBoost = ((cache.auctionDepth <= state.auctionLength) ? cache.auctionDepth : state.auctionLength) * 1e14 / state.auctionLength * uint16(state.tickSpread);
        cache.inputBoosted = cache.input * (1e18 + cache.auctionBoost) / 1e18;

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (priceLimit > nextPrice) {
                // stop at price limit
                nextPrice = priceLimit;
            }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price, false);
            // check if we can increase input to account for auction
            // if we can't, subtract amount inputted at the end
            // store amountInDelta in pool either way
            // putting in less either way
            if (cache.inputBoosted <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = FullPrecisionMath.mulDivRoundingUp(
                    liquidityPadded,
                    cache.price,
                    liquidityPadded + cache.price * cache.inputBoosted
                );
                /// @auditor - check tests to see if we need overflow handle
                // if (!(nextTickPrice <= newPrice && newPrice < cache.price)) {
                //     console.log('overflow check');
                //     newPrice = uint160(FullPrecisionMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                // }
                amountOut = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                cache.price = uint160(newPrice);
                cache.amountInDelta = FullPrecisionMath.mulDiv(maxDx - maxDx * cache.input / cache.inputBoosted, Q96, cache.liquidity);
                cache.input = 0;
            } else if (maxDx > 0) {
                amountOut = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                cache.price = nextPrice;
                cache.amountInDelta = FullPrecisionMath.mulDiv(maxDx - maxDx * cache.input / cache.inputBoosted, Q96, cache.liquidity);
                cache.input -= maxDx * cache.input / cache.inputBoosted; /// @dev - convert back to input amount
            }
        } else {
            // Price is increasing.
            if (priceLimit < nextPrice) {
                // stop at price limit
                nextPrice = priceLimit;
            }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextPrice, false);
            if (cache.inputBoosted <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.inputBoosted, Q96, cache.liquidity);
                // Calculate output of swap
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                cache.price = newPrice;
                cache.amountInDelta = FullPrecisionMath.mulDiv(cache.inputBoosted - cache.input, Q96, cache.liquidity);
                cache.input = 0;
            } else if (maxDy > 0) {
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                cache.price = nextPrice;
                cache.amountInDelta = FullPrecisionMath.mulDiv(maxDy - maxDy * cache.input / cache.inputBoosted, Q96, cache.liquidity);
                cache.input -= maxDy * cache.input / cache.inputBoosted + 1; /// @dev - handles rounding errors with amountInDelta
            }
        }
        return (cache, amountOut);
    }

    function initialize(
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1,
        ICoverPoolStructs.GlobalState memory state
    ) external returns (ICoverPoolStructs.GlobalState memory) {
        /// @dev - assume latestTick is not MIN_TICK or MAX_TICK
        // if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) revert InvalidLatestTick();
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = TwapOracle.initializePoolObservations(
                state.inputPool,
                state.twapLength
            );
            if (state.unlocked == 1) {

                state.latestTick = (state.latestTick / int24(state.tickSpread)) * int24(state.tickSpread);
                state.latestPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
                state.auctionStart = uint32(block.number - state.genesisBlock);
                state.accumEpoch = 1;

                tickNodes[state.latestTick] = ICoverPoolStructs.TickNode(
                    TickMath.MIN_TICK,
                    TickMath.MAX_TICK,
                    state.accumEpoch
                );
                tickNodes[TickMath.MIN_TICK] = ICoverPoolStructs.TickNode(
                    TickMath.MIN_TICK,
                    state.latestTick,
                    state.accumEpoch
                );
                tickNodes[TickMath.MAX_TICK] = ICoverPoolStructs.TickNode(
                    state.latestTick,
                    TickMath.MAX_TICK,
                    state.accumEpoch
                );

                pool0.price = TickMath.getSqrtRatioAtTick(state.latestTick - state.tickSpread);
                pool1.price = TickMath.getSqrtRatioAtTick(state.latestTick + state.tickSpread);
            }
        }
        return state;
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
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();
        if ((uint128(type(int128).max) - state.liquidityGlobal) < amount)
            revert LiquidityOverflow();
        ICoverPoolStructs.Tick memory tickLower = ticks[lower];
        ICoverPoolStructs.Tick memory tickUpper = ticks[upper];
        /// @auditor lower or upper = latestTick -> should not be possible
        /// @auditor - should we check overflow/underflow of lower and upper ticks?
        /// @auditor - we need to be able to deprecate pools if necessary; so not much reason to do overflow/underflow check
        if (tickNodes[lower].nextTick != tickNodes[lower].previousTick) {
            // tick exists
            if (isPool0) {
                tickLower.liquidityDelta -= int128(amount);
                tickLower.liquidityDeltaMinus += amount;
            } else {
                tickLower = _dilute(tickLower, amount);
                tickLower.liquidityDelta += int128(amount);
            }
        } else {
            // tick does not exist
            if (isPool0) {
                tickLower = ICoverPoolStructs.Tick(-int128(amount), amount, 0, 0, 0, 0, 0);
            } else {
                tickLower = ICoverPoolStructs.Tick(int128(amount), 0, 0, 0, 0, 0, 0);
            }
            /// @auditor new latestTick being in between lowerOld and lower handled by Positions.validate()
            int24 oldNextTick = tickNodes[lowerOld].nextTick;
            if (upper < oldNextTick) {
                oldNextTick = upper;
            }
            /// @auditor - don't set previous tick so upper can be initialized
            else {
                tickNodes[oldNextTick].previousTick = lower;
            }

            if (lowerOld >= lower || lower >= oldNextTick) {
                revert WrongTickLowerOld();
            }
            tickNodes[lower] = ICoverPoolStructs.TickNode(lowerOld, oldNextTick, 0);
            tickNodes[lowerOld].nextTick = lower;
        }
        /// @auditor -> is it safe to add to liquidityDelta w/o Tick struct initialization
        if (tickNodes[upper].nextTick != tickNodes[upper].previousTick) {
            if (isPool0) {
                tickUpper = _dilute(tickUpper, amount);
                tickUpper.liquidityDelta += int128(amount);
            } else {
                tickUpper.liquidityDelta -= int128(amount);
                tickUpper.liquidityDeltaMinus += amount;
            }
        } else {
            if (isPool0) {
                tickUpper = ICoverPoolStructs.Tick(int128(amount), 0, 0, 0, 0, 0, 0);
            } else {
                tickUpper = ICoverPoolStructs.Tick(-int128(amount), amount, 0, 0, 0, 0, 0);
            }
            int24 oldPrevTick = tickNodes[upperOld].previousTick;
            if (lower > oldPrevTick) oldPrevTick = lower;
            //TODO: handle new TWAP being in between upperOld and upper
            /// @dev - if nextTick == previousTick this tick node is uninitialized
            if (
                tickNodes[upperOld].nextTick == tickNodes[upperOld].previousTick ||
                upperOld <= upper ||
                upper <= oldPrevTick
            ) {
                revert WrongTickUpperOld();
            }
            tickNodes[upper] = ICoverPoolStructs.TickNode(oldPrevTick, upperOld, 0);
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
                    if (amount == tickLower.liquidityDeltaMinus) {
                        tickLower = _filter(tickLower, false);
                    }
                    tickLower.liquidityDelta += int128(amount);
                    tickLower.liquidityDeltaMinus -= amount;
                } else {
                    // if amount is 100% of liquidity added filter out carry deltas
                    if (
                        amount == uint128(tickLower.liquidityDelta) + tickLower.liquidityDeltaMinus
                    ) {
                        _filter(tickLower, true);
                    }
                    tickLower.liquidityDelta -= int128(amount);
                }
            } else {
                if (isPool0) {
                    if (lower == upper) {
                        if (amount == tickLower.liquidityDeltaMinusInactive) {
                            tickLower = _filter(tickLower, false);
                        }
                    }
                    console.log('lower tick inactive:', tickLower.liquidityDeltaMinusInactive);
                    console.log(amount);
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
                    // if amount is 100% of liquidity added filter out carry deltas
                    if (
                        amount == uint128(tickUpper.liquidityDelta) + tickUpper.liquidityDeltaMinus
                    ) {
                        _filter(tickUpper, true);
                    }
                    tickUpper.liquidityDelta -= int128(amount);
                } else {
                    if (amount == tickUpper.liquidityDeltaMinus) {
                        tickUpper = _filter(tickUpper, false);
                    }
                    tickUpper.liquidityDelta += int128(amount);
                    tickUpper.liquidityDeltaMinus -= amount;
                }
            } else {
                if (!isPool0) {
                    if (lower == upper) {
                        if (amount == tickUpper.liquidityDeltaMinusInactive) {
                            tickUpper = _filter(tickUpper, false);
                        }
                    }
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

    function _dilute(ICoverPoolStructs.Tick memory tick, uint128 amount)
        internal
        pure
        returns (ICoverPoolStructs.Tick memory)
    {
        if (tick.amountInDeltaCarryPercent > 0) {
            //adjust deltas for liquidity being added
            uint256 liquidityDeltaPlus = uint128(
                tick.liquidityDelta + int128(tick.liquidityDeltaMinus)
            );
            {
                // adjust amountIn delta values
                uint256 amountInDeltaCarry = (uint256(tick.amountInDelta) *
                    uint256(tick.amountInDeltaCarryPercent)) / 1e18;
                tick.amountInDelta -= uint128(amountInDeltaCarry);
                uint256 amountInCarryNew = uint128(
                    FullPrecisionMath.mulDiv(
                        FullPrecisionMath.mulDiv(amountInDeltaCarry, liquidityDeltaPlus, Q96),
                        Q96,
                        liquidityDeltaPlus + amount
                    )
                );
                tick.amountInDeltaCarryPercent = uint64(
                    (amountInCarryNew * tick.amountInDelta) / 1e18
                );
                tick.amountInDelta += uint128(amountInCarryNew);
            }
            if (tick.amountOutDeltaCarryPercent > 0) {
                // adjust amountOut delta values
                uint256 amountOutDeltaCarry = (uint256(tick.amountOutDelta) *
                    uint256(tick.amountOutDeltaCarryPercent)) / 1e18;
                tick.amountOutDelta -= uint128(amountOutDeltaCarry);
                uint256 amountOutCarryNew = uint128(
                    FullPrecisionMath.mulDiv(
                        FullPrecisionMath.mulDiv(amountOutDeltaCarry, liquidityDeltaPlus, Q96),
                        Q96,
                        liquidityDeltaPlus + amount
                    )
                );
                tick.amountOutDeltaCarryPercent = uint64(
                    (amountOutCarryNew * tick.amountOutDelta) / 1e18
                );
                tick.amountOutDelta += uint128(amountOutCarryNew);
            }
        }
        return tick;
    }

    function _filter(ICoverPoolStructs.Tick memory tick, bool filterCarry)
        internal
        pure
        returns (ICoverPoolStructs.Tick memory)
    {
        if (filterCarry) {
            if (tick.amountInDeltaCarryPercent > 0) {
                // filter out deltas being carried to next tick
                {
                    tick.amountInDelta -= uint128(
                        (uint256(tick.amountInDelta) * uint256(tick.amountInDeltaCarryPercent)) /
                            1e18
                    );
                    tick.amountInDeltaCarryPercent = 0;
                }
                if (tick.amountOutDeltaCarryPercent > 0) {
                    tick.amountOutDelta -= uint128(
                        (uint256(tick.amountOutDelta) * uint256(tick.amountOutDeltaCarryPercent)) /
                            1e18
                    );
                    tick.amountOutDeltaCarryPercent = 0;
                }
            }
        } else {
            if (tick.amountInDeltaCarryPercent > 0) {
                // filter out deltas left on tick
                {
                    tick.amountInDelta = uint128(
                        (uint256(tick.amountInDelta) * uint256(tick.amountInDeltaCarryPercent)) /
                            1e18
                    );
                    tick.amountInDeltaCarryPercent = 1e18;
                }
                if (tick.amountOutDeltaCarryPercent > 0) {
                    tick.amountOutDelta = uint128(
                        (uint256(tick.amountOutDelta) * uint256(tick.amountOutDeltaCarryPercent)) /
                            1e18
                    );
                    tick.amountOutDeltaCarryPercent = 1e18;
                }
            } else {
                tick.amountInDelta = 0;
                tick.amountOutDelta = 0;
            }
        }
        return tick;
    }
}
