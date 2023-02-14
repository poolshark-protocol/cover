// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface ICoverPoolStructs {
    struct GlobalState {
        uint8 unlocked;
        //TODO: change swapFee to uint16
        uint16 swapFee; /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
        //TODO: change to uint16
        int16 tickSpread; /// @dev this is a integer multiple of the inputPool tickSpacing
        uint16 twapLength; /// @dev number of blocks used for TWAP sampling
        int24 latestTick; /// @dev latest updated inputPool price tick
        uint32 genesisBlock; /// @dev reference block for which auctionStart is an offset of
        uint32 lastBlock;    /// @dev last block checked
        uint32 auctionStart; /// @dev last block price reference was updated
        uint16 auctionLength; /// @dev number of blocks to improve price by tickSpread
        uint32 accumEpoch;
        uint128 liquidityGlobal;
        uint160 latestPrice; /// @dev price of latestTick
    }

    //TODO: adjust nearestTick if someone burns all liquidity from current nearestTick
    struct PoolState {
        uint128 liquidity; /// @dev Liquidity currently active
        uint128 amountInDelta; /// @dev Delta for the current tick auction
        uint160 price; /// @dev Starting price current
    }

    struct TickNode {
        int24 previousTick;
        int24 nextTick;
        uint32 accumEpochLast; // Used to check for claim updates
    }

    struct Tick {
        int128 liquidityDelta; //TODO: if feeGrowthGlobalIn > position.feeGrowthGlobal don't update liquidity
        uint128 liquidityDeltaMinus; // represent LPs for token0 -> token1
        uint128 liquidityDeltaMinusInactive;
        //TODO: change to uint since we know in is negative and out is positive
        uint128 amountInDelta; //TODO: amount deltas are Q24x64 ; should always be negative?
        uint128 amountOutDelta; //TODO: make sure this won't overflow if amount is unfilled; should always be positive
        uint64 amountInDeltaCarryPercent;
        uint64 amountOutDeltaCarryPercent;
        //TODO: wrap amountDeltas in a single struct
    }

    // balance needs to be immediately transferred to the position owner
    struct Position {
        uint128 liquidity; // expected amount to be used not actual
        uint32 accumEpochLast; // last feeGrowth this position was updated at
        uint160 claimPriceLast; // highest price claimed at
        uint128 amountIn; // token amount already claimed; balance
        uint128 amountOut; // necessary for non-custodial positions
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
        uint256 amountInDelta;
    }

    struct PositionCache {
        Position position;
        uint160 priceLower;
        uint160 priceUpper;
    }

    struct UpdatePositionCache {
        Position position;
        uint160 priceLower;
        uint160 priceUpper;
        uint160 claimPrice;
        TickNode claimTick;
        bool removeLower;
        bool removeUpper;
        uint128 amountInDelta;
        uint128 amountOutDelta;
    }

    struct AccumulateCache {
        int24 nextTickToCross0;
        int24 nextTickToCross1;
        int24 nextTickToAccum0;
        int24 nextTickToAccum1;
        int24 stopTick0;
        int24 stopTick1;
        uint128 amountInDelta0;
        uint128 amountInDelta1;
        uint128 amountOutDelta0;
        uint128 amountOutDelta1;
    }

    struct AccumulateOutputs {
        uint128 amountInDelta;
        uint128 amountOutDelta;
        TickNode accumTickNode;
        Tick crossTick;
        Tick accumTick;
    }
}
