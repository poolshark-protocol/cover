// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
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
        ICoverPoolStructs.BurnCache memory cache,
        ICoverPoolStructs.TickMap storage tickMap,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions
    ) external returns (ICoverPoolStructs.BurnCache memory) {
       if (cache.position.claimPriceLast > 0
            || params.claim != (params.zeroForOne ? params.upper : params.lower) 
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
                    ICoverPoolStructs.UpdateParams(
                        msg.sender,
                        params.to,
                        params.burnPercent,
                        params.lower,
                        params.upper,
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
                    ICoverPoolStructs.UpdateParams(
                        msg.sender,
                        params.to,
                        params.burnPercent,
                        params.lower,
                        params.upper,
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
                ICoverPoolStructs.RemoveParams(
                    msg.sender,
                    params.to,
                    params.burnPercent,
                    params.lower,
                    params.upper,
                    params.zeroForOne
                ),
                cache.constants
            );
        }
        Collect.burn(
            cache,
            positions,
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
