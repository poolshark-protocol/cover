// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

abstract contract CoverPoolFactoryEvents {
    event PoolCreated(
        address pool,
        address indexed inputPool,
        address token0,
        address token1,
        uint16 fee,
        int16 tickSpread,
        uint16 twapLength,
        uint16 indexed poolTypeId
    );
}
