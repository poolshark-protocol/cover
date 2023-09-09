//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import '../interfaces/external/poolshark/range/IRangePoolFactory.sol';
import './RangePoolMock.sol';

contract RangePoolFactoryMock is IRangePoolFactory {
    address mockPool;
    address mockPool2;
    address owner;

    mapping(uint24 => int24) public feeTierTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public rangePools;

    constructor(address tokenA, address tokenB) {
        owner = msg.sender;
        require(tokenA < tokenB, 'wrong token order');

        feeTierTickSpacing[500] = 10;
        feeTierTickSpacing[3000] = 60;
        feeTierTickSpacing[10000] = 200;

        // create mock pool 1
        mockPool = address(new RangePoolMock(tokenA, tokenB, 500, 10));
        rangePools[tokenA][tokenB][500] = mockPool;

        // create mock pool 2
        mockPool2 = address(new RangePoolMock(tokenA, tokenB, 3000, 60));
        rangePools[tokenA][tokenB][3000] = mockPool2;
    }

    function getRangePool(
        address tokenIn,
        address tokenOut,
        uint16 feeTier
    ) external view override returns (address) {
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        
        return rangePools[token0][token1][feeTier];
    }
}
