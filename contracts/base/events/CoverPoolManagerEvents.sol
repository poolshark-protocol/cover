// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

abstract contract CoverPoolManagerEvents {
    event FactoryChanged(address indexed previousFactory, address indexed newFactory);
    event VolatilityTierEnabled(
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        uint16  auctionLength,
        uint16  blockTime,
        int16   minPositionWidth,
        uint128 minAmountPerAuction,
        bool    minLowerPriced
    );
    event FeeToTransfer(address indexed previousFeeTo, address indexed newFeeTo);
    event OwnerTransfer(address indexed previousOwner, address indexed newOwner);
    event ProtocolFeeUpdated(uint16 oldProtocolFee, uint16 newProtocolFee);
    event ProtocolFeeCollected(address indexed pool, uint128 token0Fees, uint128 token1Fees);
}