// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Epochs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';

library SwapCall {
    event SwapPool0(
        address indexed recipient,
        uint128 amountIn,
        uint128 amountOut,
        uint160 priceLimit,
        uint160 newPrice
    );

    event SwapPool1(
        address indexed recipient,
        uint128 amountIn,
        uint128 amountOut,
        uint160 priceLimit,
        uint160 newPrice
    );

    function perform(
        ICoverPool.SwapParams memory params,
        ICoverPoolStructs.SwapCache memory cache,
        ICoverPoolStructs.GlobalState storage globalState,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1
    ) external returns (ICoverPoolStructs.SwapCache memory) {
        SafeTransfers.transferIn(params.zeroForOne ? cache.constants.token0 : cache.constants.token1, params.amount);
        {
            ICoverPoolStructs.PoolState memory pool = params.zeroForOne ? cache.pool1 : cache.pool0;
            cache = ICoverPoolStructs.SwapCache({
                state: cache.state,
                syncFees: cache.syncFees,
                constants: cache.constants,
                pool0: cache.pool0,
                pool1: cache.pool1,
                price: pool.price,
                liquidity: pool.liquidity,
                amountLeft: params.amount,
                auctionDepth: block.timestamp - cache.constants.genesisTime - cache.state.auctionStart,
                auctionBoost: 0,
                input: 0,
                output: 0,
                amountBoosted: 0,
                amountInDelta: 0,
                exactIn: true
            });
        }
        /// @dev - liquidity range is limited to one tick
        cache = Ticks.quote(params.zeroForOne, params.priceLimit, cache.state, cache, cache.constants);

        if (params.zeroForOne) {
            cache.pool1.price = uint160(cache.price);
            cache.pool1.amountInDelta += uint128(cache.amountInDelta);
        } else {
            cache.pool0.price = uint160(cache.price);
            cache.pool0.amountInDelta += uint128(cache.amountInDelta);
        }

        // save state to storage before callback
        save(cache, globalState, pool0, pool1);
    
        if (params.zeroForOne) {
            if (cache.amountLeft + cache.syncFees.token0 > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token0, cache.amountLeft + cache.syncFees.token0);
            }
            if (cache.output + cache.syncFees.token1 > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token1, cache.output + cache.syncFees.token1);
                emit SwapPool1(params.to, uint128(cache.input), uint128(cache.output), uint160(cache.price), params.priceLimit);
            }
        } else {
            if (cache.amountLeft + cache.syncFees.token1 > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token1, cache.amountLeft + cache.syncFees.token1);
            }
            if (cache.output + cache.syncFees.token0 > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token0, cache.output + cache.syncFees.token0);
                emit SwapPool0(params.to, uint128(cache.input), uint128(cache.output), uint160(cache.price), params.priceLimit);
            }
        }
        return cache;
    }

    function save(
        ICoverPoolStructs.SwapCache memory cache,
        ICoverPoolStructs.GlobalState storage globalState,
        ICoverPoolStructs.PoolState storage pool0,
        ICoverPoolStructs.PoolState storage pool1
    ) internal {
        globalState.latestPrice = cache.state.latestPrice;
        globalState.liquidityGlobal = cache.state.liquidityGlobal;
        globalState.lastTime = cache.state.lastTime;
        globalState.auctionStart = cache.state.auctionStart;
        globalState.accumEpoch = cache.state.accumEpoch;
        globalState.latestTick = cache.state.latestTick;

        pool0.price = cache.pool0.price;
        pool0.liquidity = cache.pool0.liquidity;
        pool0.amountInDelta = cache.pool0.amountInDelta;
        pool0.amountInDeltaMaxClaimed = cache.pool0.amountInDeltaMaxClaimed;
        pool0.amountOutDeltaMaxClaimed = cache.pool0.amountOutDeltaMaxClaimed;

        pool1.price = cache.pool1.price;
        pool1.liquidity = cache.pool1.liquidity;
        pool1.amountInDelta = cache.pool1.amountInDelta;
        pool1.amountInDeltaMaxClaimed = cache.pool1.amountInDeltaMaxClaimed;
        pool1.amountOutDeltaMaxClaimed = cache.pool1.amountOutDeltaMaxClaimed;
    }
}
