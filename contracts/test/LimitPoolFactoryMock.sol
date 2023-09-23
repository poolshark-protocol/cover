//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import '../interfaces/external/poolshark/limit/ILimitPoolFactory.sol';
import './LimitPoolMock.sol';

contract LimitPoolFactoryMock is ILimitPoolFactory {
    address mockPool;
    address mockPool2;
    address owner;

    mapping(uint24 => int24) public feeTierTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public limitPools;

    constructor(address tokenA, address tokenB) {
        owner = msg.sender;
        require(tokenA < tokenB, 'wrong token order');

        feeTierTickSpacing[500] = 10;
        feeTierTickSpacing[3000] = 60;
        feeTierTickSpacing[10000] = 200;

        // create mock pool 1
        mockPool = address(new LimitPoolMock(tokenA, tokenB, 500, 10));
        limitPools[tokenA][tokenB][500] = mockPool;

        // create mock pool 2
        mockPool2 = address(new LimitPoolMock(tokenA, tokenB, 3000, 60));
        limitPools[tokenA][tokenB][3000] = mockPool2;
    }

    function getLimitPool(
        bytes32 poolType,
        address tokenIn,
        address tokenOut,
        uint16 feeTier
    ) external view override returns (address pool, address poolToken) {
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        poolType;
        poolToken;
        
        pool = limitPools[token0][token1][feeTier];
    }
}
