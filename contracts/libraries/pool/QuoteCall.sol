// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Ticks.sol';


library QuoteCall {

    function perform(
        ICoverPoolStructs.QuoteParams memory params,
        ICoverPoolStructs.SwapCache memory cache
    ) external view returns (
        ICoverPoolStructs.SwapCache memory
    ) {
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
            amountIn: params.amountIn,
            auctionDepth: block.timestamp - cache.constants.genesisTime - cache.state.auctionStart,
            auctionBoost: 0,
            input: params.amountIn,
            output: 0,
            inputBoosted: 0,
            amountInDelta: 0
        });
    }
        cache = Ticks.quote(params.zeroForOne, params.priceLimit, cache.state, cache, cache.constants);
        return cache;
    }
}
