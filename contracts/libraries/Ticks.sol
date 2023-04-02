// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import '../interfaces/ICoverPoolStructs.sol';
import '../utils/CoverPoolErrors.sol';
import './math/FullPrecisionMath.sol';
import './math/DyDxMath.sol';
import './TwapOracle.sol';
import './TickMap.sol';
// import 'hardhat/console.sol';

/// @notice Tick management library for ranged liquidity.
library Ticks {
    //TODO: alphabetize errors
    error NotImplementedYet();
    error InvalidLatestTick();
    error LiquidityOverflow();
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOld();
    error WrongTickUpperOld();
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
                cache.input -= maxDx * (1e18 - cache.auctionBoost) / 1e18; /// @dev - convert back to input amount
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
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextPrice, false);
                cache.price = nextPrice;
                cache.input -= maxDy * (1e18 - cache.auctionBoost) / 1e18; 
                cache.amountInDelta = cache.amountIn - cache.input;
            }
        }
        return (cache, amountOut);
    }

    function initialize(
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1,
        ICoverPoolStructs.GlobalState memory state
    ) external returns (ICoverPoolStructs.GlobalState memory) {
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = TwapOracle.initializePoolObservations(
                state.inputPool,
                state.twapLength
            );
            if (state.unlocked == 1) {
                // initialize state
                state.latestTick = (state.latestTick / int24(state.tickSpread)) * int24(state.tickSpread);
                state.latestPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
                state.auctionStart = uint32(block.number - state.genesisBlock);
                state.accumEpoch = 1;

                // initialize ticks
                TickMap.set(tickMap, TickMath.MIN_TICK);
                TickMap.set(tickMap, TickMath.MAX_TICK);
                TickMap.set(tickMap, state.latestTick);

                // initialize price
                pool0.price = TickMath.getSqrtRatioAtTick(state.latestTick - state.tickSpread);
                pool1.price = TickMath.getSqrtRatioAtTick(state.latestTick + state.tickSpread);
            }
        }
        return state;
    }

    function insert(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        int24 lower,
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
        /// @auditor lower or upper = latestTick -> should not be possible
        /// @auditor - should we check overflow/underflow of lower and upper ticks?
        /// @auditor - we need to be able to deprecate pools if necessary; so not much reason to do overflow/underflow check

        // sets bit in map
        TickMap.set(tickMap, lower);

        // updates liquidity values
        if (isPool0) {
                tickLower.liquidityDelta -= int128(amount);
                tickLower.liquidityDeltaMinus += amount;
        } else {
                tickLower.liquidityDelta += int128(amount);
        }

        TickMap.set(tickMap, upper);

        if (isPool0) {
                tickUpper.liquidityDelta += int128(amount);
        } else {
            tickUpper.liquidityDelta -= int128(amount);
            tickUpper.liquidityDeltaMinus += amount;
        }
        ticks[lower] = tickLower;
        ticks[upper] = tickUpper;

        // state.liquidityGlobal += amount;
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
