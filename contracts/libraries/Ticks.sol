// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../interfaces/modules/curves/ICurveMath.sol';
import '../interfaces/ICoverPoolStructs.sol';
import '../utils/CoverPoolErrors.sol';
import './math/FullPrecisionMath.sol';
import '../interfaces/modules/curves/ICurveMath.sol';
import '../interfaces/modules/sources/ITwapSource.sol';
import './TickMap.sol';

/// @notice Tick management library for ranged liquidity.
library Ticks {
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    event Initialize(
        int24 minTick,
        int24 maxTick,
        int24 latestTick,
        uint32 genesisTime,
        uint32 auctionStart,
        uint160 pool0Price,
        uint160 pool1Price
    );

    function quote(
        bool zeroForOne,
        uint160 priceLimit,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.SwapCache memory cache,
        ICoverPoolStructs.Immutables memory constants
    ) external pure returns (ICoverPoolStructs.SwapCache memory) {
        if ((zeroForOne ? priceLimit >= cache.price 
                        : priceLimit <= cache.price) 
            || cache.liquidity == 0 
            || cache.input == 0
        )
            return cache;
        uint256 nextPrice = state.latestPrice;
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
            uint256 maxDx = constants.curve.getDx(cache.liquidity, nextPrice, cache.price, false);
            // check if all input is used
            if (cache.inputBoosted <= maxDx) {
                // calculate price after swap
                uint256 newPrice = constants.curve.getNewPrice(cache.price, cache.liquidity, cache.inputBoosted, zeroForOne);
                cache.output += constants.curve.getDy(cache.liquidity, newPrice, cache.price, false);
                cache.price = newPrice;
                cache.input = 0;
                cache.amountInDelta = cache.amountIn;
            } else if (maxDx > 0) {
                cache.output += constants.curve.getDy(cache.liquidity, nextPrice, cache.price, false);
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
            uint256 maxDy = constants.curve.getDy(cache.liquidity, cache.price, nextPrice, false);
            if (cache.inputBoosted <= maxDy) {
                // calculate price after swap
                uint256 newPrice = constants.curve.getNewPrice(cache.price, cache.liquidity, cache.inputBoosted, zeroForOne);
                cache.output += constants.curve.getDx(cache.liquidity, cache.price, newPrice, false);
                cache.price = newPrice;
                cache.input = 0;
                cache.amountInDelta = cache.amountIn;
            } else if (maxDy > 0) {
                cache.output += constants.curve.getDx(cache.liquidity, cache.price, nextPrice, false);
                cache.price = nextPrice;
                cache.input -= maxDy * (1e18 - cache.auctionBoost) / 1e18; 
                cache.amountInDelta = cache.amountIn - cache.input;
            }
        }
        return (cache);
    }

    function initialize(
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants 
    ) external returns (ICoverPoolStructs.GlobalState memory) {
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = constants.source.initialize(constants);
            if (state.unlocked == 1) {
                // initialize state
                state.latestTick = (state.latestTick / int24(constants.tickSpread)) * int24(constants.tickSpread);
                state.latestPrice = constants.curve.getPriceAtTick(state.latestTick, constants);
                state.auctionStart = uint32(block.timestamp - constants.genesisTime);
                state.accumEpoch = 1;

                // initialize ticks
                TickMap.set(constants.curve.minTick(constants.tickSpread), tickMap, constants);
                TickMap.set(constants.curve.maxTick(constants.tickSpread), tickMap, constants);
                TickMap.set(state.latestTick, tickMap, constants);

                // initialize price
                pool0.price = constants.curve.getPriceAtTick(state.latestTick - constants.tickSpread, constants);
                pool1.price = constants.curve.getPriceAtTick(state.latestTick + constants.tickSpread, constants);
            
                emit Initialize(
                    constants.curve.minTick(constants.tickSpread),
                    constants.curve.maxTick(constants.tickSpread),
                    state.latestTick,
                    constants.genesisTime,
                    state.auctionStart,
                    pool0.price,
                    pool1.price
                );
            }
        }
        return state;
    }

    function insert(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants,
        int24 lower,
        int24 upper,
        uint128 amount,
        bool isPool0
    ) external {
        /// @dev - validation of ticks is in Positions.validate
        if (amount > uint128(type(int128).max)) require (false, 'LiquidityOverflow()');
        if ((uint128(type(int128).max) - state.liquidityGlobal) < amount)
            require (false, 'LiquidityOverflow()');

        // load ticks into memory to reduce reads/writes
        ICoverPoolStructs.Tick memory tickLower = ticks[lower];
        ICoverPoolStructs.Tick memory tickUpper = ticks[upper];

        // sets bit in map
        TickMap.set(lower, tickMap, constants);

        // updates liquidity values
        if (isPool0) {
                tickLower.liquidityDelta -= int128(amount);
        } else {
                tickLower.liquidityDelta += int128(amount);
        }

        TickMap.set(upper, tickMap, constants);

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
        ICoverPoolStructs.Immutables memory constants,
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
            if (lower != constants.curve.minTick(constants.tickSpread) && _empty(tickLower)) {
                TickMap.unset(lower, tickMap, constants);
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
            if (upper != constants.curve.maxTick(constants.tickSpread) && _empty(tickUpper)) {
                TickMap.unset(upper, tickMap, constants);
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
