// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/PositionTokens.sol';
import '../utils/Collect.sol';
import 'hardhat/console.sol';

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
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState storage globalState,
        CoverPoolStructs.PoolState storage pool0,
        CoverPoolStructs.PoolState storage pool1,
        PoolsharkStructs.BurnCoverParams memory params,
        CoverPoolStructs.BurnCache memory cache
    ) external returns (CoverPoolStructs.BurnCache memory) {
        cache.position = positions[params.positionId];
        if (PositionTokens.balanceOf(cache.constants, msg.sender, params.positionId) == 0)
            // check for balance held
            require(false, 'PositionNotFound()');
        //TODO: should check epochs here
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
        save(cache, globalState, pool0, pool1);
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

    function save(
        CoverPoolStructs.BurnCache memory cache,
        CoverPoolStructs.GlobalState storage globalState,
        CoverPoolStructs.PoolState storage pool0,
        CoverPoolStructs.PoolState storage pool1
    ) internal {
        // globalState
        globalState.protocolFees = cache.state.protocolFees;
        globalState.latestPrice = cache.state.latestPrice;
        globalState.liquidityGlobal = cache.state.liquidityGlobal;
        globalState.lastTime = cache.state.lastTime;
        globalState.auctionStart = cache.state.auctionStart;
        globalState.accumEpoch = cache.state.accumEpoch;
        globalState.positionIdNext = cache.state.positionIdNext;
        globalState.latestTick = cache.state.latestTick;
        
        // pool0
        pool0.price = cache.pool0.price;
        pool0.liquidity = cache.pool0.liquidity;
        pool0.amountInDelta = cache.pool0.amountInDelta;
        pool0.amountInDeltaMaxClaimed = cache.pool0.amountInDeltaMaxClaimed;
        pool0.amountOutDeltaMaxClaimed = cache.pool0.amountOutDeltaMaxClaimed;

        // pool1
        pool1.price = cache.pool1.price;
        pool1.liquidity = cache.pool1.liquidity;
        pool1.amountInDelta = cache.pool1.amountInDelta;
        pool1.amountInDeltaMaxClaimed = cache.pool1.amountInDeltaMaxClaimed;
        pool1.amountOutDeltaMaxClaimed = cache.pool1.amountOutDeltaMaxClaimed;
    }
}
