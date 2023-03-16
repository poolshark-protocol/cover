// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

abstract contract CoverPoolManagerEvents {
    event FactoryChanged(address indexed previousFactory, address indexed newFactory);
    event SpreadTierEnabled(uint16 feeTier, uint16 tickSpread, uint16 twapLength, uint16 auctionLength);
    event FeeToTransfer(address indexed previousFeeTo, address indexed newFeeTo);
    event OwnerTransfer(address indexed previousOwner, address indexed newOwner);
    event ProtocolFeeUpdated(uint16 oldProtocolFee, uint16 newProtocolFee);
    event ProtocolFeeCollected(address indexed pool, uint128 token0Fees, uint128 token1Fees);
}