// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/cover/ICoverPool.sol';
import '../Ticks.sol';

library QuoteCall {
    uint8 private constant _ENTERED = 2;

    function perform(
        ICoverPool.QuoteParams memory params,
        CoverPoolStructs.SwapCache memory cache
    ) external view returns (
        int256,
        int256,
        uint256
    ) {
        if (cache.state.unlocked == _ENTERED)
            require(false, 'ReentrancyGuardReadOnlyReentrantCall()');
        {
            CoverPoolStructs.PoolState memory pool = params.zeroForOne ? cache.pool1 : cache.pool0;
            cache = CoverPoolStructs.SwapCache({
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
        // call quote
        cache = Ticks.quote(
            params.zeroForOne,
            params.priceLimit,
            cache.state,
            cache,
            cache.constants
        );

        // calculate deltas
        cache = calculateDeltas(params, cache);
        
        return (
            params.zeroForOne ? -cache.amount0Delta : -cache.amount1Delta,
            params.zeroForOne ? cache.amount1Delta : cache.amount0Delta,
            cache.price
        );
    }

    function calculateDeltas(
        ICoverPool.QuoteParams memory params,
        CoverPoolStructs.SwapCache memory cache
    ) internal pure returns (
        CoverPoolStructs.SwapCache memory
    ) {
        // calculate amount deltas
        cache.amount0Delta = params.zeroForOne ? -int256(cache.input) 
                                               : int256(cache.output);
        cache.amount1Delta = params.zeroForOne ? int256(cache.output) 
                                               : -int256(cache.input);
        
        // factor in sync fees
        cache.amount0Delta += int128(cache.syncFees.token0);
        cache.amount1Delta += int128(cache.syncFees.token1);

        return cache;
    }
}
