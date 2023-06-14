// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';

library MintCall {
    event Mint(
        address indexed to,
        int24 lower,
        int24 upper,
        bool zeroForOne,
        uint32 epochLast,
        uint128 amountIn,
        uint128 liquidityMinted,
        uint128 amountInDeltaMaxMinted,
        uint128 amountOutDeltaMaxMinted
    );

    function perform(
        ICoverPool.MintParams memory params,
        ICoverPoolStructs.MintCache memory cache,
        ICoverPoolStructs.TickMap storage tickMap,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions
    ) external returns (ICoverPoolStructs.MintCache memory) {
        // resize position if necessary
        (params, cache.liquidityMinted) = Positions.resize(
            cache.position,
            params, 
            cache.state,
            cache.constants
        );
        // params.amount must be > 0 here
        SafeTransfers.transferIn(params.zeroForOne ? cache.constants.token0 
                                                   : cache.constants.token1,
                                 params.amount
                                );

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
                params.upper,
                params.zeroForOne
            ),
            cache.constants
        );
        Collect.mint(
            cache,
            ICoverPoolStructs.CollectParams(
                cache.syncFees,
                params.to,
                params.lower,
                0, // not needed for mint collect
                params.upper,
                params.zeroForOne
            )
        );
        positions[params.to][params.lower][params.upper] = cache.position;
        return cache;
    }
}
