// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface ICoverPoolStructs {
    struct GlobalState {
        uint24 swapFee;         /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
        int24  tickSpread;      /// @dev this is a integer multiple of the inputPool tickSpacing
        uint32 lastBlockNumber; /// @dev last block checked for reference price update
        uint8  unlocked;
        int24  latestTick;      /// @dev Latest updated inputPool price tick
        uint32 accumEpoch;
    }
    
    //TODO: adjust nearestTick if someone burns all liquidity from current nearestTick
    struct PoolState {
        uint128 liquidity;             /// @dev Liquidity currently active
        uint128 feeGrowthCurrentEpoch; /// @dev Global fee growth per liquidity unit in current epoch
        uint160 price;                 /// @dev Starting price current
        int24   nearestTick;           /// @dev Tick below current price
        int24   lastTick;              /// @dev Last tick accumulated to
    }

    struct TickNode {
        int24    previousTick;
        int24    nextTick;
        uint32   accumEpochLast;   // Used to check for claim updates
    }

    struct Tick {
        int104  liquidityDelta;      //TODO: if feeGrowthGlobalIn > position.feeGrowthGlobal don't update liquidity
        uint104 liquidityDeltaMinus; // represent LPs for token0 -> token1
        int88   amountInDelta;       //TODO: amount deltas are Q24x64 ; should always be negative?
        int88   amountOutDelta;      //TODO: make sure this won't overflow if amount is unfilled; should always be positive
        uint64  amountInDeltaCarryPercent;
        uint64  amountOutDeltaCarryPercent;
    }
 
    // balance needs to be immediately transferred to the position owner
    struct Position {
        uint128 liquidity;           // expected amount to be used not actual
        uint32  accumEpochLast;      // last feeGrowth this position was updated at
        uint160 claimPriceLast;      // highest price claimed at
        uint128 amountIn;            // token amount already claimed; balance
        uint128 amountOut;           // necessary for non-custodial positions
    }

    //TODO: should we have a recipient field here?
    struct AddParams {
        address owner;
        int24 lowerOld;
        int24 lower;
        int24 upper;
        int24 upperOld;
        bool zeroForOne;
        uint128 amount;
    }

    struct RemoveParams {
        address owner;
        int24 lower;
        int24 upper;
        bool zeroForOne;
        uint128 amount;
    }

    struct UpdateParams {
        address owner;
        int24 lower;
        int24 upper;
        int24 claim;
        bool zeroForOne;
        int128 amount;
    }

    struct ValidateParams {
        int24 lowerOld;
        int24 lower;
        int24 upper;
        int24 upperOld;
        bool zeroForOne;
        uint128 amount;
        GlobalState state;
    }

    //TODO: optimize this struct
    struct SwapCache {
        uint256 price;
        uint256 liquidity;
        uint256 feeAmount;
        uint256 input;
    }

    struct PositionCache {
        Position position;
        uint160 priceLower;
        uint160 priceUpper;
    }

    struct UpdatePositionCache {
        Position position;
        uint232 feeGrowthCurrentEpoch;
        uint160 priceLower;
        uint160 priceUpper;
        uint160 claimPrice;
        TickNode claimTick;
        bool removeLower;
        bool removeUpper;
        int128 amountInDelta;
        int128 amountOutDelta;
    }

    struct AccumulateCache {
        int24   nextTickToCross0;
        int24   nextTickToCross1;
        int24   nextTickToAccum0;
        int24   nextTickToAccum1;
        int24   stopTick0;
        int24   stopTick1;
        int128  amountInDelta0; 
        int128  amountInDelta1; 
        int128  amountOutDelta0;
        int128  amountOutDelta1;
    }
}
    
    
