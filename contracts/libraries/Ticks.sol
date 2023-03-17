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
    ) external pure returns (ICoverPoolStructs.SwapCache memory, uint256 amountOut) {
        if (zeroForOne ? priceLimit >= cache.price 
                       : priceLimit <= cache.price 
            || cache.price == 0 
            || cache.input == 0
        )
            return (cache, 0);
        uint256 nextTickPrice = state.latestPrice;
        uint256 nextPrice = nextTickPrice;

        // determine input boost from tick auction
        cache.auctionBoost = ((cache.auctionDepth <= state.auctionLength) ? cache.auctionDepth 
                                                                          : state.auctionLength
                             ) * 1e14 / state.auctionLength * uint16(state.tickSpread);
        cache.inputBoosted = cache.input * (1e18 + cache.auctionBoost) / 1e18;

        if (zeroForOne) {
            // trade token 0 (x) for token 1 (y)
            // price decreases
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
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = FullPrecisionMath.mulDivRoundingUp(
                    liquidityPadded,
                    cache.price,
                    liquidityPadded + cache.price * cache.inputBoosted
                );
                amountOut = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                cache.price = uint160(newPrice);
                cache.input = 0;
                cache.amountInDelta = cache.amountIn;
            } else if (maxDx > 0) {
                amountOut = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                cache.price = nextPrice;
                cache.input -= maxDx * cache.input / cache.inputBoosted; /// @dev - convert back to input amount
                cache.amountInDelta = cache.amountIn - cache.input;
            }
        } else {
            // price increases
            if (priceLimit < nextPrice) {
                // stop at price limit
                nextPrice = priceLimit;
            }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextPrice, false);
            if (cache.inputBoosted <= maxDy) {
                // calculate price after swap
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.inputBoosted, Q96, cache.liquidity);
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                cache.price = newPrice;
                cache.input = 0;
                cache.amountInDelta = cache.amountIn;
            } else if (maxDy > 0) {
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                cache.price = nextPrice;
                cache.input -= maxDy * cache.input / cache.inputBoosted + 1; /// @dev - handles rounding errors with amountInDelta
                cache.amountInDelta = cache.amountIn - cache.input;
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
    ) external {
        /// @auditor - validation of ticks is in Positions.validate
        // load into memory to reduce storage reads/writes
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();
        if ((uint128(type(int128).max) - state.liquidityGlobal) < amount)
            revert LiquidityOverflow();
        ICoverPoolStructs.Tick memory tickLower = ticks[lower];
        ICoverPoolStructs.Tick memory tickUpper = ticks[upper];
        ICoverPoolStructs.TickNode memory tickNodeLower = tickNodes[lower];
        ICoverPoolStructs.TickNode memory tickNodeUpper = tickNodes[upper];
        /// @auditor lower or upper = latestTick -> should not be possible
        /// @auditor - should we check overflow/underflow of lower and upper ticks?
        /// @auditor - we need to be able to deprecate pools if necessary; so not much reason to do overflow/underflow check
        if (tickNodeLower.nextTick != tickNodeLower.previousTick) {
            // tick exists
            if (isPool0) {
                tickLower.liquidityDelta -= int128(amount);
                tickLower.liquidityDeltaMinus += amount;
            } else {
                tickLower.liquidityDelta += int128(amount);
            }
            if (upper == tickNodes[upperOld].previousTick) {
                tickNodeLower.nextTick = upper;
            }
        } else {
            // tick does not exist
            if (isPool0) {
                tickLower = ICoverPoolStructs.Tick(-int128(amount), amount, 0, 0, ICoverPoolStructs.Deltas(0, 0, 0, 0));
            } else {
                tickLower = ICoverPoolStructs.Tick(int128(amount), 0, 0, 0, ICoverPoolStructs.Deltas(0, 0, 0, 0));
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
            tickNodeLower = ICoverPoolStructs.TickNode(lowerOld, oldNextTick, 0);
            tickNodes[lowerOld].nextTick = lower;
        }

        /// @auditor -> is it safe to add to liquidityDelta w/o Tick struct initialization
        if (tickNodeUpper.nextTick != tickNodeUpper.previousTick) {
            if (isPool0) {
                tickUpper.liquidityDelta += int128(amount);
            } else {
                tickUpper.liquidityDelta -= int128(amount);
                tickUpper.liquidityDeltaMinus += amount;
            }
            console.log('tick check');
            console.logInt(upper);
            console.logInt(lower);
            console.logInt(tickNodes[lowerOld].nextTick);
            if (lower == tickNodes[lowerOld].nextTick) {
                tickNodeUpper.previousTick = lower;
            }
        } else {
            if (isPool0) {
                tickUpper = ICoverPoolStructs.Tick(int128(amount), 0, 0, 0, ICoverPoolStructs.Deltas(0, 0, 0, 0));
            } else {
                tickUpper = ICoverPoolStructs.Tick(-int128(amount), amount, 0, 0, ICoverPoolStructs.Deltas(0, 0, 0, 0));
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
            tickNodeUpper = ICoverPoolStructs.TickNode(oldPrevTick, upperOld, 0);
            tickNodes[oldPrevTick].nextTick = upper;
            tickNodes[upperOld].previousTick = upper;
        }
        ticks[lower] = tickLower;
        ticks[upper] = tickUpper;
        tickNodes[lower] = tickNodeLower;
        tickNodes[upper] = tickNodeUpper;
    }

    function remove(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        int24 lower,
        int24 upper,
        uint128 amount,
        // uint128 amountStashed,
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
            }
            /// @dev - not deleting ticks just yet
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
            }
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
}
