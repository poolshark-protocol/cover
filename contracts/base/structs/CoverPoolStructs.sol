// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract CoverPoolStructs {
    struct CoverPoolParams {
        uint128 minAmountPerAuction; // based on 18 decimals and then converted based on token decimals
        address inputPool;
        uint16  twapLength;
        uint16  auctionLength;
        int16   tickSpread;
        uint8   minPositionWidth;
    }
}