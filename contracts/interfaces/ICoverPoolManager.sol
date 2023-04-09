// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @notice CoverPoolManager interface
interface ICoverPoolManager {
    struct CoverPoolConfig {
        uint16  auctionLength;
        uint16  minPositionWidth;
        uint128 minAuctionAmount; // based on 18 decimals and then converted based on token decimals
    }
    function owner() external view returns (address);
    function feeTo() external view returns (address);
    function protocolFee() external view returns (uint16);
    function volatilityTiers(
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external view returns (
        uint16,
        uint16,
        uint128
    );
}
