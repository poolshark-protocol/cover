// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/ICoverPool.sol';
import '../Ticks.sol';


library QuoteCall {

    function perform(
        ICoverPool.QuoteParams memory params,
        CoverPoolStructs.SwapCache memory cache
    ) external view returns (
        CoverPoolStructs.SwapCache memory
    ) {
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
        cache = Ticks.quote(params.zeroForOne, params.priceLimit, cache.state, cache, cache.constants);
        return cache;
    }
}
