// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../../interfaces/ITwapSource.sol';

interface CoverPoolManagerStructs {
    struct VolatilityTier {
        uint128 minAmountPerAuction; // based on 18 decimals and then converted based on token decimals
        uint16  auctionLength;
        uint16  blockTime; // average block time where 1e3 is 1 second
        uint16  syncFee;
        uint16  fillFee;
        int16   minPositionWidth;
        bool    minAmountLowerPriced;
    }
}