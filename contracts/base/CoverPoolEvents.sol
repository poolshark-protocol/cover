// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract CoverPoolEvents {

    event Mint(
        address indexed owner,
        int24 indexed lower,
        int24 indexed upper,
        bool zeroForOne,
        uint128 liquidityMinted
    );

    event Burn(
        address indexed owner,
        int24 indexed lower,
        int24 indexed upper,
        bool zeroForOne,
        uint128 liquidityBurned
    );

    //TODO: implement Collect event for subgraph
    event Collect(
        address indexed sender, 
        uint256 amount0, 
        uint256 amount1
    );

    event Swap(
        address indexed recipient, 
        address indexed tokenIn, 
        address indexed tokenOut, 
        uint256 amountIn,
        uint256 amountOut
    );

    event PoolCreated(
        address pool,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    );
}