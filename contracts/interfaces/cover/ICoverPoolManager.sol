// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';

/// @notice CoverPoolManager interface
interface ICoverPoolManager is CoverPoolStructs {
    function owner() external view returns (address);
    function feeTo() external view returns (address);
    function poolTypes(
        bytes32 poolType
    ) external view returns (
        address implAddress,
        address sourceAddress
    );
    function volatilityTiers(
        bytes32 implName,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external view returns (
        VolatilityTier memory
    );
}
