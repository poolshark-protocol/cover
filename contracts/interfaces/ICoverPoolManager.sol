// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

/// @notice Range Pool Interface
interface ICoverPoolManager {
    function owner() external view returns (address);
    function feeTo() external view returns (address);
    function protocolFee() external view returns (uint16);
    function spreadTiers(
        uint16 feeTier,
        uint16 tickSpread,
        uint16 twapLength
    ) external view returns (uint16);
}
