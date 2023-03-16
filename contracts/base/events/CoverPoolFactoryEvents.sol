// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

abstract contract CoverPoolFactoryEvents {
    event PoolCreated(
        address pool,
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpread,
        uint16 twapLength,
        uint16 auctionLength
    );

    event ProtocolFeeCollected(
        address pool,
        uint128 token0Fees,
        uint128 token1Fees
    );
}
