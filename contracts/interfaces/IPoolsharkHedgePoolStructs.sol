// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPoolsharkHedgePoolStructs {

    struct Tick {
        int24 previousTick;
        int24 nextTick;
        uint128 liquidity;
        uint256 feeGrowthOutside0; // Per unit of liquidity.
        uint256 feeGrowthOutside1;
        uint160 secondsGrowthOutside;
    }
    
    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0Last;
        uint256 feeGrowthInside1Last;
    }

    struct MintParams {
        int24 lowerOld;
        int24 lower;
        int24 upperOld;
        int24 upper;
        uint128 amount0Desired;
        uint128 amount1Desired;
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
    
    
