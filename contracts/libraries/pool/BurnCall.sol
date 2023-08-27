// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/Collect.sol';

library BurnCall {
    event Burn(
        address indexed to,
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityBurned,
        uint128 tokenInClaimed,
        uint128 tokenOutClaimed,
        uint128 tokenOutBurned,
        uint128 amountInDeltaMaxStashedBurned,
        uint128 amountOutDeltaMaxStashedBurned,
        uint128 amountInDeltaMaxBurned,
        uint128 amountOutDeltaMaxBurned,
        uint160 claimPriceLast
    );

    function perform(
        ICoverPool.BurnParams memory params,
        CoverPoolStructs.BurnCache memory cache,
        CoverPoolStructs.TickMap storage tickMap,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions
    ) external returns (CoverPoolStructs.BurnCache memory) {
        cache.position = positions[params.positionId];
        if (cache.position.owner != msg.sender) {
            require(false, 'PositionNotFound()');
        }
       if (cache.position.claimPriceLast > 0
            || params.claim != (params.zeroForOne ? cache.position.upper : cache.position.lower) 
            || params.claim == cache.state.latestTick)
        {
            // if position has been crossed into
            if (params.zeroForOne) {
                (
                    cache.state,
                    cache.pool0,
                    params.claim
                ) = Positions.update(
                    positions,
                    ticks,
                    tickMap,
                    cache.state,
                    cache.pool0,
                    CoverPoolStructs.UpdateParams(
                        msg.sender,
                        params.to,
                        params.burnPercent,
                        params.positionId,
                        cache.position.lower,
                        cache.position.upper,
                        params.claim,
                        params.zeroForOne
                    ),
                    cache.constants
                );
            } else {
                (
                    cache.state,
                    cache.pool1,
                    params.claim
                ) = Positions.update(
                    positions,
                    ticks,
                    tickMap,
                    cache.state,
                    cache.pool1,
                    CoverPoolStructs.UpdateParams(
                        msg.sender,
                        params.to,
                        params.burnPercent,
                        params.positionId,
                        cache.position.lower,
                        cache.position.upper,
                        params.claim,
                        params.zeroForOne
                    ),
                    cache.constants
                );
            }
        } else {
            // if position hasn't been crossed into
            (, cache.state) = Positions.remove(
                positions,
                ticks,
                tickMap,
                cache.state,
                CoverPoolStructs.RemoveParams(
                    msg.sender,
                    params.to,
                    params.burnPercent,
                    params.positionId,
                    cache.position.lower,
                    cache.position.upper,
                    params.zeroForOne
                ),
                cache.constants
            );
        }
        Collect.burn(
            cache,
            positions,
            CoverPoolStructs.CollectParams(
                cache.syncFees,
                params.to, //address(0) goes to msg.sender
                params.positionId,
                cache.position.lower,
                params.claim,
                cache.position.upper,
                params.zeroForOne
            )
        );
        return cache;
    }
}
