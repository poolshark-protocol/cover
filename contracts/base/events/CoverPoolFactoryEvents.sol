// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

abstract contract CoverPoolFactoryEvents {
    event PoolCreated(
        address pool,
        address inputPool,
        address indexed token0,
        address indexed token1,
        uint16 indexed fee,
        int16 tickSpread,
        uint16 twapLength
    );

    event ProtocolFeeCollected(
        address pool,
        uint128 token0Fees,
        uint128 token1Fees
    );
}
