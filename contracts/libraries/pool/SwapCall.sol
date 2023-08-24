// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../../interfaces/IERC20Minimal.sol';
import '../../interfaces/callbacks/ICoverPoolSwapCallback.sol';
import '../Epochs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';
import '../utils/SafeCast.sol';

library SwapCall {
    using SafeCast for int256;

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
                amount0Delta: 0,
                amount1Delta: 0,
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

        // calculate amount deltas
        cache.amount0Delta = params.zeroForOne ? -int256(cache.input) 
                                               : int256(cache.output);
        cache.amount1Delta = params.zeroForOne ? int256(cache.output) 
                                               : -int256(cache.input);
        
        // factor in sync fees
        cache.amount0Delta += int128(cache.syncFees.token0);
        cache.amount1Delta += int128(cache.syncFees.token1);

        // transfer swap output
        SafeTransfers.transferOut(
            params.to,
            params.zeroForOne ? cache.constants.token1
                              : cache.constants.token0,
            params.zeroForOne ? cache.amount1Delta.toUint256()
                              : cache.amount0Delta.toUint256()
        );

        // check balance and execute callback
        uint256 balanceStart = balance(params, cache);
        ICoverPoolSwapCallback(msg.sender).coverPoolSwapCallback(
            cache.amount0Delta,
            cache.amount1Delta,
            params.callbackData
        );

        // check balance requirements after callback
        if (balance(params, cache) < balanceStart + cache.input)
            require(false, 'SwapInputAmountTooLow()');
    
        if (params.zeroForOne) {
            // transfer out if sync fees > swap input
            if (cache.amount0Delta > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token0, cache.amount0Delta.toUint256());
            }
            emit SwapPool1(params.to, uint128(cache.input), uint128(cache.output), uint160(cache.price), params.priceLimit);
        } else {
            if (cache.amount1Delta > 0) {
                SafeTransfers.transferOut(params.to, cache.constants.token1, cache.amount1Delta.toUint256());
            }
            emit SwapPool0(params.to, uint128(cache.input), uint128(cache.output), uint160(cache.price), params.priceLimit);
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

    function balance(
        ICoverPool.SwapParams memory params,
        ICoverPoolStructs.SwapCache memory cache
    ) private view returns (uint256) {
        (
            bool success,
            bytes memory data
        ) = (params.zeroForOne ? cache.constants.token0
                               : cache.constants.token1)
                               .staticcall(
                                    abi.encodeWithSelector(
                                        IERC20Minimal.balanceOf.selector,
                                        address(this)
                                    )
                                );
        if(!success || data.length < 32) require(false, 'InvalidERC20ReturnData()');
        return abi.decode(data, (uint256));
    }
}
