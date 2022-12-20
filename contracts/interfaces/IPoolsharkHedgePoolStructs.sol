// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface IPoolsharkHedgePoolStructs {

    struct PoolState {
        int24   nearestTick;       /// @dev Tick below current price
        uint160 price;             /// @dev Starting price current
        uint128 liquidity;         /// @dev Liquidity currently active
        uint256 feeGrowthGlobalIn; /// @dev Global fee growth per liquidity unit
    }

    struct TickNode {
        int24    previousTick;
        int24    nextTick;
    }

    struct Tick {
        int128   liquidityDelta;      //TODO: if feeGrowthGlobalIn > position.feeGrowthGlobal don't update liquidity
        uint128  liquidityDeltaMinus; // represent LPs for token0 -> token1
        uint256  feeGrowthGlobalIn;   // Used to check for claim updates
        int128   amountInDelta; 
        int128   amountOutDelta;
        int128   amountInDeltaCarry;
        int128   amountOutDeltaCarry;
    }

    // feeGrowthGlobalInitial 
    // balance needs to be immediately transferred to the position owner
    struct Position {
        uint128 liquidity;           // expected amount to be used not actual
        uint256 feeGrowthGlobalIn; // last feeGrowth this position was updated at
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
        uint256 price;
        uint256 liquidity;
        uint256 feeAmount;
        uint256 input;
    }

    struct UpdatePositionCache {
        Position position;
        uint256 feeGrowthGlobalIn;
        uint160 priceLower;
        uint160 priceUpper;
        uint160 claimPrice;
        bool removeLower;
        bool removeUpper;
        int24 upperRemove;
        int24 lowerRemove;
    }

    struct AccumulateCache {
        int24   nextTickToCross0;
        int24   nextTickToCross1;
        int24   nextTickToAccum0;
        int24   nextTickToAccum1;
        int24   stopTick0;
        int24   stopTick1;
        uint160 price0;
        uint160 price1;
        uint128 liquidity0;
        uint128 liquidity1;
        int128   amountInDelta0; 
        int128   amountInDelta1; 
        int128   amountOutDelta0;
        int128   amountOutDelta1;

    }
}
    
    
