// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './CoverPoolManagerStructs.sol';

abstract contract CoverPoolFactoryStructs is CoverPoolManagerStructs {
    struct CoverPoolParams {
        VolatilityTier config;
        address twapSource;
        address inputPool;
        address manager;
        address token0;
        address token1;
        int16   tickSpread;
        uint16  twapLength;
    }
}




