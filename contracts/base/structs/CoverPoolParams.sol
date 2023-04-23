

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface CoverPoolParams {
    struct MintParams {
        address to;
        uint128 amount;
        int24 lower;
        int24 claim;
        int24 upper;
        bool zeroForOne;
    }

    struct BurnParams {
        address to;
        uint128 amount;
        int24 lower;
        int24 claim;
        int24 upper;
        bool zeroForOne;
        bool sync;
    }
}