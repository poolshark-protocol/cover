// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPoolsharkHedgePoolStructs {

    struct Tick {
        int24 previousTick;
        int24 nextTick;
        uint128 amount0; // Claimable token amounts
        uint128 amount1;
        uint128 liquidity0; // represent LPs for token0 -> token1
        uint128 liquidity1; // represent LPs for token1 -> token0
        uint256 feeGrowthGlobal0; // Used to check for claim updates
        uint256 feeGrowthGlobal1;
        uint160 averageSqrtPrice0;
        uint160 averageSqrtPrice1;
        uint160 secondsGrowthOutside;
    }

    // feeGrowthGlobalInitial 
    // balance needs to be immediately transferred to the position owner
    struct Position {
        uint128 liquidity;           // expected amount to be used not actual
        uint256 feeGrowthGlobalLast; // last feeGrowth this position was updated at
        int24   highestTickClaimed;  // highest tick claimed at
        uint128 amountClaimed;       // token amount already claimed; balance
    }

    //TODO: should we have a recipient field here?
    struct MintParams {
        int24 lowerOld;
        int24 lower;
        int24 upperOld;
        int24 upper;
        uint128 amount0Desired;
        uint128 amount1Desired;
        bool zeroForOne;
        bool native;
    }

    struct SwapCache {
        uint256 feeAmount;
        uint256 totalFeeAmount;
        uint256 protocolFee;
        uint256 feeGrowthGlobalA;
        uint256 feeGrowthGlobalB;
        uint256 currentSqrtPrice;
        uint256 currentLiquidity;
        uint256 input;
        int24 nextTickToCross;
    }    
}
    
    
