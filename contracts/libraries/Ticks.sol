// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import '../interfaces/structs/CoverPoolStructs.sol';
import '../utils/CoverPoolErrors.sol';
import './math/OverflowMath.sol';
import '../interfaces/modules/sources/ITwapSource.sol';
import './TickMap.sol';
import 'hardhat/console.sol';

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
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.SwapCache memory cache,
        PoolsharkStructs.CoverImmutables memory constants
    ) internal pure returns (CoverPoolStructs.SwapCache memory) {
        if ((zeroForOne ? priceLimit >= cache.price
                        : priceLimit <= cache.price) ||
            (cache.liquidity == 0))
        {
            return cache;
        }
        uint256 nextPrice = state.latestPrice;
        // determine input boost from tick auction
        cache.auctionBoost = ((cache.auctionDepth <= constants.auctionLength) ? cache.auctionDepth
                                                                              : constants.auctionLength
                             ) * 1e14 / constants.auctionLength * uint16(constants.tickSpread);
        cache.amountBoosted = cache.amountLeft;
        if (cache.exactIn)
            cache.amountBoosted = cache.amountLeft * (1e18 + cache.auctionBoost) / 1e18;
        if (zeroForOne) {
            // trade token 0 (x) for token 1 (y)
            // price decreases
            if (priceLimit > nextPrice) {
                // stop at price limit
                nextPrice = priceLimit;
            }
            // max input or output that we can get
            uint256 amountMax = cache.exactIn ? ConstantProduct.getDx(cache.liquidity, nextPrice, cache.price, true)
                                              : ConstantProduct.getDy(cache.liquidity, nextPrice, cache.price, false);
            // check if all input is used
            if (cache.amountBoosted <= amountMax) {
                // calculate price after swap
                uint256 newPrice = ConstantProduct.getNewPrice(
                    cache.price,
                    cache.liquidity,
                    cache.amountBoosted,
                    zeroForOne,
                    cache.exactIn
                );
                if (cache.exactIn) {
                    cache.input = cache.amountLeft;
                    cache.output = ConstantProduct.getDy(cache.liquidity, newPrice, cache.price, false);
                } else {
                    // input needs to be adjusted based on boost
                    cache.input = ConstantProduct.getDx(cache.liquidity, newPrice, uint256(cache.price), true) * (1e18 - cache.auctionBoost) / 1e18;
                    cache.output = cache.amountLeft;
                }
                cache.price = newPrice;
                cache.amountLeft = 0;
            } else if (amountMax > 0) {
                if (cache.exactIn) {
                    cache.input = amountMax * (1e18 - cache.auctionBoost) / 1e18; /// @dev - convert back to input amount
                    cache.output = ConstantProduct.getDy(cache.liquidity, nextPrice, cache.price, false);
                } else {
                    // input needs to be adjusted based on boost
                    cache.input = ConstantProduct.getDx(cache.liquidity, nextPrice, cache.price, true) * (1e18 - cache.auctionBoost) / 1e18;
                    cache.output = amountMax;
                }
                cache.price = nextPrice;
                cache.amountLeft -= cache.exactIn ? cache.input : cache.output;
            }
        } else {
            // price increases
            if (priceLimit < nextPrice) {
                // stop at price limit
                nextPrice = priceLimit;
            }
            uint256 amountMax = cache.exactIn ? ConstantProduct.getDy(cache.liquidity, uint256(cache.price), nextPrice, true)
                                              : ConstantProduct.getDx(cache.liquidity, uint256(cache.price), nextPrice, false);
            if (cache.amountBoosted <= amountMax) {
                // calculate price after swap
                uint256 newPrice = ConstantProduct.getNewPrice(
                    cache.price,
                    cache.liquidity,
                    cache.amountBoosted,
                    zeroForOne,
                    cache.exactIn
                );
                if (cache.exactIn) {
                    cache.input = cache.amountLeft;
                    cache.output = ConstantProduct.getDx(cache.liquidity, cache.price, newPrice, false);
                } else {
                    // input needs to be adjusted based on boost
                    cache.input = ConstantProduct.getDy(cache.liquidity, cache.price, newPrice, true) * (1e18 - cache.auctionBoost) / 1e18;
                    cache.output = cache.amountLeft;
                }
                cache.price = newPrice;
                cache.amountLeft = 0;
            } else if (amountMax > 0) {
                if (cache.exactIn) {
                    cache.input = amountMax * (1e18 - cache.auctionBoost) / 1e18; 
                    cache.output = ConstantProduct.getDx(cache.liquidity, cache.price, nextPrice, false);
                } else {
                    // input needs to be adjusted based on boost
                    cache.input = ConstantProduct.getDy(cache.liquidity, cache.price, nextPrice, true) * (1e18 - cache.auctionBoost) / 1e18;
                    cache.output = amountMax;
                }
                cache.price = nextPrice;
                cache.amountLeft -= cache.exactIn ? cache.input : cache.output;
            }
        }
        cache.amountInDelta = cache.input;
        return cache;
    }

    function initialize(
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.PoolState storage pool0,
        CoverPoolStructs.PoolState storage pool1,
        CoverPoolStructs.GlobalState storage state,
        PoolsharkStructs.CoverImmutables memory constants 
    ) external {
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = constants.source.initialize(constants);
            if (state.unlocked == 1) {
                // initialize state
                state.latestTick = (state.latestTick / int24(constants.tickSpread)) * int24(constants.tickSpread);
                state.latestPrice = ConstantProduct.getPriceAtTick(state.latestTick, constants);
                state.auctionStart = uint32(block.timestamp - constants.genesisTime);
                state.accumEpoch = 1;
                state.positionIdNext = 1;

                // initialize ticks
                TickMap.set(ConstantProduct.minTick(constants.tickSpread), tickMap, constants);
                TickMap.set(ConstantProduct.maxTick(constants.tickSpread), tickMap, constants);
                TickMap.set(state.latestTick, tickMap, constants);

                // initialize price
                pool0.price = ConstantProduct.getPriceAtTick(state.latestTick - constants.tickSpread, constants);
                pool1.price = ConstantProduct.getPriceAtTick(state.latestTick + constants.tickSpread, constants);
            
                emit Initialize(
                    ConstantProduct.minTick(constants.tickSpread),
                    ConstantProduct.maxTick(constants.tickSpread),
                    state.latestTick,
                    constants.genesisTime,
                    state.auctionStart,
                    pool0.price,
                    pool1.price
                );
            }
        }
    }

    function insert(
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        PoolsharkStructs.CoverImmutables memory constants,
        int24 lower,
        int24 upper,
        uint128 amount,
        bool isPool0
    ) internal {
        /// @dev - validation of ticks is in Positions.validate
        if (amount > uint128(type(int128).max)) require (false, 'LiquidityOverflow()');
        if ((uint128(type(int128).max) - state.liquidityGlobal) < amount)
            require (false, 'LiquidityOverflow()');

        // load ticks into memory to reduce reads/writes
        CoverPoolStructs.Tick memory tickLower = ticks[lower];
        CoverPoolStructs.Tick memory tickUpper = ticks[upper];

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
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        PoolsharkStructs.CoverImmutables memory constants,
        int24 lower,
        int24 upper,
        uint128 amount,
        bool isPool0,
        bool removeLower,
        bool removeUpper
    ) internal {
        {
            CoverPoolStructs.Tick memory tickLower = ticks[lower];
            if (removeLower) {
                if (isPool0) {
                    tickLower.liquidityDelta += int128(amount);
                } else {
                    tickLower.liquidityDelta -= int128(amount);
                }
                ticks[lower] = tickLower;
            }
            if (lower != ConstantProduct.minTick(constants.tickSpread)) {
                cleanup(ticks, tickMap, constants, tickLower, lower);
            }
        }
        {
            CoverPoolStructs.Tick memory tickUpper = ticks[upper];
            if (removeUpper) {
                if (isPool0) {
                    tickUpper.liquidityDelta -= int128(amount);
                } else {
                    tickUpper.liquidityDelta += int128(amount);
                }
                ticks[upper] = tickUpper;
            }
            if (upper != ConstantProduct.maxTick(constants.tickSpread)) {
                cleanup(ticks, tickMap, constants, tickUpper, upper);
            }
        }
    }

    function cleanup(
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        PoolsharkStructs.CoverImmutables memory constants,
        CoverPoolStructs.Tick memory tick,
        int24 tickIndex
    ) internal {
        if (!_empty(tick)){
            // if one of the values is 0 clear out both
            if (tick.amountInDeltaMaxMinus == 0 || tick.amountOutDeltaMaxMinus == 0) {
                tick.amountInDeltaMaxMinus = 0;
                tick.amountOutDeltaMaxMinus = 0;
            }
            if (tick.amountInDeltaMaxStashed == 0 || tick.amountOutDeltaMaxStashed == 0) {
                tick.amountInDeltaMaxStashed = 0;
                tick.amountOutDeltaMaxStashed = 0;
            }
            if (_inactive(tick)) {
                // zero out all values for safety
                tick.amountInDeltaMaxMinus = 0;
                tick.amountOutDeltaMaxMinus = 0;
                tick.amountInDeltaMaxStashed = 0;
                tick.amountOutDeltaMaxStashed = 0;
                TickMap.unset(tickIndex, tickMap, constants);
            }
        }
        if (_empty(tick)) {
            TickMap.unset(tickIndex, tickMap, constants);
            delete ticks[tickIndex];
        } else {
            ticks[tickIndex] = tick;
        }
    }

    function _inactive(
        CoverPoolStructs.Tick memory tick
    ) internal pure returns (
        bool
    ) {
        if (tick.amountInDeltaMaxStashed > 0 && tick.amountOutDeltaMaxStashed > 0) {
            return false;
        } else if (tick.amountInDeltaMaxMinus > 0 && tick.amountOutDeltaMaxMinus > 0){
            return false;
        } else if (tick.liquidityDelta != 0) {
            return false;
        }
        return true;
    }

    function _empty(
        CoverPoolStructs.Tick memory tick
    ) internal pure returns (
        bool
    ) {
        if (tick.amountInDeltaMaxStashed > 0 && tick.amountOutDeltaMaxStashed > 0) {
            return false;
        } else if (tick.amountInDeltaMaxMinus > 0 && tick.amountOutDeltaMaxMinus > 0){
            return false;
        } else if (tick.liquidityDelta != 0) {
            return false;
        } else if (tick.deltas0.amountInDeltaMax > 0 && tick.deltas0.amountOutDeltaMax > 0) {
            return false;
        } else if (tick.deltas1.amountInDeltaMax > 0 && tick.deltas1.amountOutDeltaMax > 0) {
            return false;
        }
        return true;
    }
}
