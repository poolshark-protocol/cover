// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';

library RandomLib {
    function random(
        ICoverPoolStructs.MintParams memory params,
        ICoverPoolStructs.MintCache memory cache,
        ICoverPoolStructs.TickMap storage tickMap,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks
    ) external returns (ICoverPoolStructs.MintCache memory) {
        // resize position if necessary
        (params, cache.liquidityMinted) = Positions.resize(
            cache.position,
            params, 
            cache.state,
            cache.constants
        );
        // params.amount must be > 0 here
        SafeTransfers.transferIn(params.zeroForOne ? cache.constants.token0 : cache.constants.token1, params.amount);

        (cache.state, cache.position) = Positions.add(
            cache.position,
            ticks,
            tickMap,
            cache.state,
            ICoverPoolStructs.AddParams(
                params.to,
                uint128(cache.liquidityMinted),
                params.amount,
                params.lower,
                params.claim,
                params.upper,
                params.zeroForOne
            ),
            cache.constants
        );
        Collect.mint(
            cache,
            ICoverPoolStructs.CollectParams(
                cache.syncFees,
                params.to, //address(0) goes to msg.sender
                params.lower,
                params.claim,
                params.upper,
                params.zeroForOne
            )
        );
        return cache;
    }
}
