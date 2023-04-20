// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @notice CoverPoolManager interface
interface ICoverPoolManager {
    struct CoverPoolConfig {
        uint128 minAmountPerAuction; // based on 18 decimals and then converted based on token decimals
        uint16  auctionLength;
        int16   minPositionWidth;
        bool    minLowerPriced;
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
        int16,
        uint128,
        bool
    );
}
