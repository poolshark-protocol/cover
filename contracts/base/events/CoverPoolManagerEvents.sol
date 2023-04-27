// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

abstract contract CoverPoolManagerEvents {
    event FactoryChanged(address indexed previousFactory, address indexed newFactory);
    event VolatilityTierEnabled(
        bytes32 sourceName,
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        uint128 minAmountPerAuction,
        uint16  auctionLength,
        uint16  blockTime,
        uint16  syncFee,
        uint16  fillFee,
        int16   minPositionWidth,
        bool    minLowerPriced
    );
    event TwapSourceEnabled(
        bytes32  sourceName,
        address sourceAddress,
        address factoryAddress
    );
    event FeeToTransfer(address indexed previousFeeTo, address indexed newFeeTo);
    event OwnerTransfer(address indexed previousOwner, address indexed newOwner);
    event ProtocolFeeUpdated(uint16 oldProtocolFee, uint16 newProtocolFee);
    event ProtocolFeeCollected(address indexed pool, uint128 token0Fees, uint128 token1Fees);
}