// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './CoverPoolManagerStructs.sol';

abstract contract CoverPoolFactoryStructs is CoverPoolManagerStructs {
    struct CoverPoolParams {
        CoverPoolConfig config;
        address inputPool;
        int16   tickSpread;
        uint16  twapLength;
    }
}




