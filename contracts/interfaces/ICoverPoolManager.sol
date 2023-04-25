// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../base/structs/CoverPoolManagerStructs.sol';

/// @notice CoverPoolManager interface
interface ICoverPoolManager is CoverPoolManagerStructs {
    function owner() external view returns (address);
    function feeTo() external view returns (address);
    function protocolFee() external view returns (uint16);
    function twapSources(
        bytes32 sourceName
    ) external view returns (
        address sourceAddress
    );
    function volatilityTiers(
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external view returns (
        CoverPoolConfig memory
    );
}
