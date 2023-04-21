// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import '../interfaces/ICoverPoolStructs.sol';
import '../utils/CoverPoolErrors.sol';
import './math/FullPrecisionMath.sol';
import './math/DyDxMath.sol';
import './TwapOracle.sol';
import './TickMap.sol';

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
        ICoverPoolStructs.SwapCache memory cache,
        ICoverPoolStructs.Immutables memory constants
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
        cache.auctionBoost = ((cache.auctionDepth <= constants.auctionLength) ? cache.auctionDepth
                                                                          : constants.auctionLength
                             ) * 1e14 / constants.auctionLength * uint16(constants.tickSpread);
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
                cache.price = newPrice;
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
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants 
    ) external returns (ICoverPoolStructs.GlobalState memory) {
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = TwapOracle.initialize(constants);
            if (state.unlocked == 1) {
                // initialize state
                state.latestTick = (state.latestTick / int24(constants.tickSpread)) * int24(constants.tickSpread);
                state.latestPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
                state.auctionStart = uint32(block.timestamp - constants.genesisTime);
                state.accumEpoch = 1;

                // initialize ticks
                TickMap.set(tickMap, TickMath.MIN_TICK);
                TickMap.set(tickMap, TickMath.MAX_TICK);
                TickMap.set(tickMap, state.latestTick);

                // initialize price
                pool0.price = TickMath.getSqrtRatioAtTick(state.latestTick - constants.tickSpread);
                pool1.price = TickMath.getSqrtRatioAtTick(state.latestTick + constants.tickSpread);
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
        /// @dev - validation of ticks is in Positions.validate
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();
        if ((uint128(type(int128).max) - state.liquidityGlobal) < amount)
            revert LiquidityOverflow();

        // load ticks into memory to reduce reads/writes
        ICoverPoolStructs.Tick memory tickLower = ticks[lower];
        ICoverPoolStructs.Tick memory tickUpper = ticks[upper];

        // sets bit in map
        TickMap.set(tickMap, lower);

        // updates liquidity values
        if (isPool0) {
                tickLower.liquidityDelta -= int128(amount);
        } else {
                tickLower.liquidityDelta += int128(amount);
        }

        TickMap.set(tickMap, upper);

        if (isPool0) {
                tickUpper.liquidityDelta += int128(amount);
        } else {
            tickUpper.liquidityDelta -= int128(amount);
        }
        ticks[lower] = tickLower;
        ticks[upper] = tickUpper;
    }

    function remove(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        int24 lower,
        int24 upper,
        uint128 amount,
        bool isPool0,
        bool removeLower,
        bool removeUpper
    ) external {
        {
            ICoverPoolStructs.Tick memory tickLower = ticks[lower];
            if (removeLower) {
                if (isPool0) {
                    tickLower.liquidityDelta += int128(amount);
                } else {
                    tickLower.liquidityDelta -= int128(amount);
                }
                ticks[lower] = tickLower;
            }
            if (lower != TickMath.MIN_TICK && _empty(tickLower)) {
                TickMap.unset(tickMap, lower);
            }
        }
        {
            ICoverPoolStructs.Tick memory tickUpper = ticks[upper];
            if (removeUpper) {
                if (isPool0) {
                    tickUpper.liquidityDelta -= int128(amount);
                } else {
                    tickUpper.liquidityDelta += int128(amount);
                }
                ticks[upper] = tickUpper;
            }
            if (upper != TickMath.MAX_TICK && _empty(tickUpper)) {
                TickMap.unset(tickMap, upper);
            }
        }
    }

    function _empty(
        ICoverPoolStructs.Tick memory tick
    ) internal pure returns (
        bool
    ) {
        if (tick.amountInDeltaMaxStashed > 0 || tick.amountOutDeltaMaxStashed > 0) {
            return false;
        } else if (tick.amountInDeltaMaxMinus > 0 || tick.amountOutDeltaMaxMinus > 0){
            return false;
        } else if (tick.deltas.amountInDeltaMax > 0 || tick.deltas.amountOutDeltaMax > 0) {
            return false;
        } else if (tick.liquidityDelta != 0) {
            return false;
        }
        return true;
    }
}
