// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract CoverPoolFactoryStructs {
    struct CoverPoolParams {
        uint128 minAmountPerAuction; // based on 18 decimals and then converted based on token decimals
        address inputPool;
        int16   tickSpread;
        int16   minPositionWidth;
        uint16  twapLength;
        uint16  auctionLength;
        uint16  blockTime;
        bool    minLowerPricedToken;
    }
}




