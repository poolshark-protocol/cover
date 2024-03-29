// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../Positions.sol';
import '../utils/PositionTokens.sol';
import '../utils/Collect.sol';

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
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState storage globalState,
        CoverPoolStructs.PoolState storage pool0,
        CoverPoolStructs.PoolState storage pool1,
        ICoverPool.MintParams memory params,
        CoverPoolStructs.MintCache memory cache
    ) external returns (CoverPoolStructs.MintCache memory) {
        if (params.positionId > 0) {
            if (PositionTokens.balanceOf(cache.constants, msg.sender, params.positionId) == 0)
                // check for balance held
                require(false, 'PositionNotFound()');
            // load existing position
            cache.position = positions[params.positionId];
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
            CoverPoolStructs.CoverPosition memory newPosition;
            newPosition.lower = params.lower;
            newPosition.upper = params.upper;
            // use new position in cache
            cache.position = newPosition;
            params.positionId = cache.state.positionIdNext;
            cache.state.positionIdNext += 1;
        }
        // save global state to protect against reentrancy
        save(cache, globalState, pool0, pool1);
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
            CoverPoolStructs.AddParams(
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
        positions[params.positionId] = cache.position;
        save(cache, globalState, pool0, pool1);
        Collect.mint(
            cache,
            CoverPoolStructs.CollectParams(
                cache.syncFees,
                params.to,
                params.positionId,
                params.lower,
                0, // not needed for mint collect
                params.upper,
                params.zeroForOne
            )
        );
        return cache;
    }

    function save(
        CoverPoolStructs.MintCache memory cache,
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
