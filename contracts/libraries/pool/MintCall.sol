// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';
import 'hardhat/console.sol';

library MintCall {
    event Mint(
        address indexed to,
        int24 lower,
        int24 upper,
        bool zeroForOne,
        uint32 positionId,
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
        mapping(uint256 => ICoverPoolStructs.CoverPosition)
            storage positions
    ) external returns (ICoverPoolStructs.MintCache memory) {
        if (params.positionId > 0) {
            // load existing position
            cache.position = positions[params.positionId];
            if (cache.position.owner != msg.sender)
                require(false, 'PositionNotFound()');
        }
        // resize position
        (params, cache.liquidityMinted) = Positions.resize(
            cache.position,
            params, 
            cache.state,
            cache.constants
        );
        if (params.positionId == 0 ||                       // new position
                params.lower != cache.position.lower ||     // lower mismatch
                params.upper != cache.position.upper) {     // upper mismatch
            ICoverPoolStructs.CoverPosition memory newPosition;
            newPosition.owner = params.to;
            newPosition.lower = params.lower;
            newPosition.upper = params.upper;
            // use new position in cache
            cache.position = newPosition;
            params.positionId = cache.state.positionIdNext;
            cache.state.positionIdNext += 1;
        }
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
                params.positionId,
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
                params.positionId,
                params.lower,
                0, // not needed for mint collect
                params.upper,
                params.zeroForOne
            )
        );
        positions[params.positionId] = cache.position;
        return cache;
    }
}
