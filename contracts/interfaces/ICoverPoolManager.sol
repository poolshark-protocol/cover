// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @notice CoverPoolManager interface
interface ICoverPoolManager {
    struct CoverPoolConfig {
        uint16  blockTime; // average block time where 1e3 is 1 second
        uint16  auctionLength;
        int16   minPositionWidth;
        uint128 minAmountPerAuction; // based on 18 decimals and then converted based on token decimals
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
        uint16,
        int16,
        uint128,
        bool
    );
}
