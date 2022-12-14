// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface IPoolsharkHedgePoolStructs {

    struct Tick {
        int24   previousTick;
        int24   nextTick;
        int128  liquidityDelta;
        uint128 liquidityDeltaMinus; // represent LPs for token0 -> token1
        uint256 feeGrowthGlobalIn; // Used to check for claim updates
        int128  amountInDeltaX96;
        int128  amountOutDeltaX96;
    }

    // feeGrowthGlobalInitial 
    // balance needs to be immediately transferred to the position owner
    struct Position {
        uint128 liquidity;           // expected amount to be used not actual
        uint256 feeGrowthGlobalLast; // last feeGrowth this position was updated at
        uint160 claimPriceLast;      // highest price claimed at
        uint128 amountIn;            // token amount already claimed; balance
        uint128 amountOut;           // necessary for non-custodial positions
    }

    //TODO: should we have a recipient field here?
    struct MintParams {
        int24 lowerOld;
        int24 lower;
        int24 upperOld;
        int24 upper;
        uint128 amountDesired;
        bool zeroForOne;
        bool native;
    }

    //TODO: optimize this struct
    struct SwapCache {
        uint256 feeAmount;
        int24   currentTick;
        uint256 currentPrice;
        uint256 currentLiquidity;
        uint256 input;
        int24 nextTickToCross;
    }

    struct AccumulateCache {
        int24   currentTick;
        uint256 currentPrice;
        uint256 currentLiquidity;
        int24   nextTickToCross;
        uint256 feeGrowthGlobal;
    }
}
    
    
