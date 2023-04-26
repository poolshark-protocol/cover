// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

abstract contract CoverPoolEvents {
    event Mint(
        address indexed owner,
        int24 indexed lower,
        int24 indexed upper,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityMinted,
        uint128 amountInDeltaMaxMinted,
        uint128 amountOutDeltaMaxMinted
    );

    event Burn(
        address indexed owner,
        address to,
        int24 indexed lower,
        int24 indexed upper,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityBurned,
        uint128 token0Amount,
        uint128 token1Amount,
        uint128 amountInDeltaMaxStashedBurned,
        uint128 amountOutDeltaMaxStashedBurned,
        uint128 amountInDeltaMaxBurned,
        uint128 amountOutDeltaMaxBurned
    );

    event Swap(
        address indexed recipient,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event SyncFeesCollected(
        address collector,
        uint128 token0Amount,
        uint128 token1Amount
    );

    event FinalDeltasAccumulated(
        bool isPool0,
        int24 accumTick,
        int24 crossTick,
        uint128 amountInDelta,
        uint128 amountOutDelta
    );

    event StashDeltasAccumulated(
        bool isPool0,
        uint128 amountInDelta,
        uint128 amountOutDelta,
        uint128 amountInDeltaMaxStashed,
        uint128 amountOutDeltaMaxStashed
    );
}
