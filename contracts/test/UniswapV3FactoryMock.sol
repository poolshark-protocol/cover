//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import '../interfaces/external/uniswap/v3/IUniswapV3Factory.sol';
import './UniswapV3PoolMock.sol';

contract UniswapV3FactoryMock is IUniswapV3Factory {
    address mockPool;
    address mockPool2;
    address owner;

    mapping(uint24 => int24) public feeTierTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor(address tokenA, address tokenB) {
        owner = msg.sender;
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB)
                                                           : (tokenB, tokenA);

        feeTierTickSpacing[500] = 10;
        feeTierTickSpacing[3000] = 60;
        feeTierTickSpacing[10000] = 200;

        // create mock pool 1
        mockPool = address(new UniswapV3PoolMock(token0, token1, 500, 10));
        getPool[token0][token1][500] = mockPool;

        // create mock pool 2
        mockPool2 = address(new UniswapV3PoolMock(token0, token1, 3000, 60));
        getPool[token0][token1][3000] = mockPool2;
    }
}
