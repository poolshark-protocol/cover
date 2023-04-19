// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./IRangePool.sol";

interface ICoverPoolStructs {
    struct GlobalState {
        uint8    unlocked;
        int16    tickSpread; /// @dev this is a integer multiple of the inputPool tickSpacing
        uint16   twapLength; /// @dev number of blocks used for TWAP sampling
        uint16   auctionLength; /// @dev number of blocks to improve price by tickSpread
        int24    latestTick;   /// @dev latest updated inputPool price tick
        uint32   genesisBlock; /// @dev reference block for which auctionStart is an offset of
        uint32   lastBlock;    /// @dev last block checked
        uint32   auctionStart; /// @dev last block price reference was updated
        uint32   accumEpoch;
        uint128  liquidityGlobal;
        uint160  latestPrice; /// @dev price of latestTick
        IRangePool inputPool;
        ProtocolFees protocolFees;
    }

    struct PoolState {
        uint128 liquidity; /// @dev Liquidity currently active
        uint128 amountInDelta; /// @dev Delta for the current tick auction
        uint128 amountInDeltaMaxClaimed;  /// @dev - needed when users claim and don't burn; should be cleared when users burn liquidity
        uint128 amountOutDeltaMaxClaimed; /// @dev - needed when users claim and don't burn; should be cleared when users burn liquidity
        uint160 price; /// @dev Starting price current
    }

    struct TickMap {
        uint256 blocks;                     /// @dev - sets of words
        mapping(uint256 => uint256) words;  /// @dev - sets to words
        mapping(uint256 => uint256) ticks;  /// @dev - words to ticks
        mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) epochs; /// @dev - ticks to epochs
    }

    struct Tick {
        int128  liquidityDelta;
        uint128 amountInDeltaMaxMinus;
        uint128 amountOutDeltaMaxMinus;
        uint128 amountInDeltaMaxStashed;
        uint128 amountOutDeltaMaxStashed;
        Deltas deltas;
    }

    struct Deltas {
        uint128 amountInDelta;     // amt unfilled
        uint128 amountOutDelta;    // amt unfilled
        uint128 amountInDeltaMax;  // max unfilled 
        uint128 amountOutDeltaMax; // max unfilled
    }

    struct Position {
        uint128 liquidity; // expected amount to be used not actual
        uint128 amountIn; // token amount already claimed; balance
        uint128 amountOut; // necessary for non-custodial positions
        uint32  accumEpochLast; // last epoch this position was updated at
        uint160 claimPriceLast; // highest price claimed at
    }

    struct Immutables {
        uint8 token0Decimals;
        uint8 token1Decimals;
        int16 minPositionWidth;
        uint256 minAmountPerAuction;
        bool minLowerPricedToken;
    }

    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }

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
        int24 lower;
        int24 claim;
        int24 upper;
        bool zeroForOne;
        uint128 amount; /// @dev - taken in as a percent
        bool sync;
    }

    struct CollectParams {
        address to;
        int24 lower;
        int24 claim;
        int24 upper;
        bool zeroForOne;
    }

    struct SizeParams {
        int24 latestTick;
        uint24 auctionCount;
        bool zeroForOne;
        uint128 liquidityAmount;
        uint256 priceLower;
        uint256 priceUpper;
    }

    struct AddParams {
        address owner;
        int24 lower;
        int24 claim;
        int24 upper;
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
        uint128 amount;
    }

    struct SwapCache {
        uint256 price;
        uint256 liquidity;
        uint256 amountIn;
        uint256 input;
        uint256 inputBoosted;
        uint256 auctionDepth;
        uint256 auctionBoost;
        uint256 amountInDelta;
    }

    struct PositionCache {
        Position position;
        uint160 priceLower;
        uint160 priceUpper;
        uint256 priceAverage;
        uint256 liquidityMinted;
        int24 requiredStart;
        uint24 auctionCount;
        bool denomTokenIn;
    }

    struct UpdatePositionCache {
        uint160 priceLower;
        uint160 priceClaim;
        uint160 priceUpper;
        uint160 priceSpread;
        bool removeLower;
        bool removeUpper;
        uint256 amountInFilledMax;    // considers the range covered by each update
        uint256 amountOutUnfilledMax; // considers the range covered by each update
        Tick claimTick;
        Tick finalTick;
        Position position;
        Deltas deltas;
        Deltas finalDeltas;
    }

    struct AccumulateCache {
        int24 nextTickToCross0;
        int24 nextTickToCross1;
        int24 nextTickToAccum0;
        int24 nextTickToAccum1;
        int24 stopTick0;
        int24 stopTick1;
        Deltas deltas0;
        Deltas deltas1;
    }

    struct AccumulateOutputs {
        Deltas deltas;
        Tick crossTick;
        Tick accumTick;
    }
}
