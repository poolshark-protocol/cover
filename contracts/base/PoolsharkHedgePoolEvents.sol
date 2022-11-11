// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract PoolsharkHedgePoolEvents {

    event Mint(
        address indexed owner,
        uint256 amount0,
        uint256 amount1
    );

    event Burn(
        address indexed owner,
        uint256 amount0,
        uint256 amount1
    );

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
        uint256 fee
    );
}