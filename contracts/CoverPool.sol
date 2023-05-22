// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/ICoverPoolManager.sol';
import './base/storage/CoverPoolStorage.sol';
import './base/structs/CoverPoolFactoryStructs.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Epochs.sol';
import './libraries/pool/SwapLib.sol';
import './libraries/pool/QuoteLib.sol';
import './libraries/pool/MintLib.sol';
import './libraries/pool/BurnLib.sol';


/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolFactoryStructs,
    CoverPoolStorage
{
    address public immutable owner;
    address public immutable token0;
    address public immutable token1;
    address public immutable twapSource;
    address public immutable curveMath;
    address public immutable inputPool; 
    uint160 public immutable minPrice;
    uint160 public immutable maxPrice;
    uint128 public immutable minAmountPerAuction;
    uint32  public immutable genesisTime;
    int16   public immutable minPositionWidth;
    int16   public immutable tickSpread;
    uint16  public immutable twapLength;
    uint16  public immutable auctionLength;
    uint16  public immutable blockTime;
    uint8   internal immutable token0Decimals;
    uint8   internal immutable token1Decimals;
    bool    public immutable minAmountLowerPriced;

    modifier ownerOnly() {
        _onlyOwner();
        _;
    }

    modifier lock() {
        _prelock();
        _;
        _postlock();
    }

    constructor(
        CoverPoolParams memory params
    ) {
        // set addresses
        owner      = params.owner;
        twapSource = params.twapSource;
        curveMath  = params.curveMath;
        inputPool  = params.inputPool;
        token0     = params.token0;
        token1     = params.token1;
        
        // set token decimals
        token0Decimals = ERC20(token0).decimals();
        token1Decimals = ERC20(token1).decimals();
        if (token0Decimals > 18 || token1Decimals > 18
          || token0Decimals < 6 || token1Decimals < 6) {
            revert InvalidTokenDecimals();
        }

        // set other immutables
        auctionLength = params.config.auctionLength;
        blockTime = params.config.blockTime;
        minPositionWidth = params.config.minPositionWidth;
        tickSpread    = params.tickSpread;
        twapLength    = params.twapLength;
        genesisTime   = uint32(block.timestamp);
        minAmountPerAuction = params.config.minAmountPerAuction;
        minAmountLowerPriced = params.config.minAmountLowerPriced;

        // set price boundaries
        ICurveMath curve = ICurveMath(curveMath);
        minPrice = curve.minPrice(tickSpread);
        maxPrice = curve.maxPrice(tickSpread);
    }

    function mint(
        MintParams memory params
    ) external override lock {
        MintCache memory cache = MintCache({
            state: globalState,
            position: params.zeroForOne ? positions0[params.to][params.lower][params.upper]
                                        : positions1[params.to][params.lower][params.upper],
            constants: _immutables(),
            syncFees: SyncFees(0,0),
            liquidityMinted: 0,
            pool0: pool0,
            pool1: pool1
        });
        (
            cache.state,
            cache.syncFees,
            cache.pool0, 
            cache.pool1
        ) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            cache.constants
        );
        cache = RandomLib.random(
            params,
            cache,
            tickMap,
            params.zeroForOne ? ticks0 : ticks1
        );
        pool0 = cache.pool0;
        pool1 = cache.pool1;
        globalState = cache.state;
    }

    function burn(
        BurnParams memory params
    ) external override lock {
        if (params.to == address(0)) revert CollectToZeroAddress();
        BurnCache memory cache = BurnCache({
            state: globalState,
            position: params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                        : positions1[msg.sender][params.lower][params.upper],
            constants: _immutables(),
            syncFees: SyncFees(0,0),
            pool0: pool0,
            pool1: pool1
        });
        if (params.sync)
            (
                cache.state,
                cache.syncFees,
                cache.pool0,
                cache.pool1
            ) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickMap,
                cache.pool0,
                cache.pool1,
                cache.state,
                cache.constants
        );
        cache = BurnLib.perform(
            params, 
            cache, 
            tickMap,
            params.zeroForOne ? ticks0 : ticks1,
            params.zeroForOne ? positions0 : positions1
        );
        pool0 = cache.pool0;
        pool1 = cache.pool1;
        globalState = cache.state;
    }

    function swap(
        SwapParams memory params
    ) external override lock returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    ) 
    {
        ICurveMath(curveMath).checkPrice(
            params.priceLimit,
            ITickMath.PriceBounds(minPrice, maxPrice));
        SwapCache memory cache;
        cache.pool0 = pool0;
        cache.pool1 = pool1;
        cache.state = globalState;
        cache.constants = _immutables();
        (
            cache.state,
            cache.syncFees,
            cache.pool0,
            cache.pool1
        ) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            _immutables()
        );

        cache = SwapLib.performSwap(params, cache);
        pool0 = cache.pool0;
        pool1 = cache.pool1;
        globalState = cache.state;

        if (params.zeroForOne) {
            return (
                int128(params.amountIn) - int256(cache.input) - int128(cache.syncFees.token0),
                cache.output + cache.syncFees.token1,
                cache.price 
            );
        } else {
            return (
                int128(params.amountIn) - int256(cache.input) - int128(cache.syncFees.token1),
                cache.output + cache.syncFees.token0,
                cache.price 
            );
        }
    }

    function quote(
        QuoteParams memory params
    ) external view override returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    ) {
        SwapCache memory cache;
        cache.pool0 = pool0;
        cache.pool1 = pool1;
        cache.state = globalState;
        cache.constants = _immutables();
        (
            cache.state,
            cache.syncFees,
            cache.pool0,
            cache.pool1
        ) = Epochs.simulateSync(
            ticks0,
            ticks1,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            cache.constants
        );
        cache = QuoteLib.perform(params, cache);
        if (params.zeroForOne) {
            return (
                int128(params.amountIn) - int256(cache.input) - int128(cache.syncFees.token0),
                cache.output + cache.syncFees.token1,
                cache.price 
            );
        } else {
            return (
                int128(params.amountIn) - int256(cache.input) - int128(cache.syncFees.token1),
                cache.output + cache.syncFees.token0,
                cache.price 
            );
        }
    }

    function snapshot(
       SnapshotParams memory params 
    ) external view override returns (
        Position memory
    ) {
        return Positions.snapshot(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickMap,
            globalState,
            params.zeroForOne ? pool0 : pool1,
            UpdateParams(
                params.owner,
                params.owner,
                params.burnPercent,
                params.lower,
                params.upper,
                params.claim,
                params.zeroForOne
            ),
            _immutables()
        );
    }

    function fees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external override ownerOnly returns (
        uint128 token0Fees,
        uint128 token1Fees
    ) {
        if (setFees) {
            globalState.syncFee = syncFee;
            globalState.fillFee = fillFee;
        }
        token0Fees = globalState.protocolFees.token0;
        token1Fees = globalState.protocolFees.token1;
        address feeTo = ICoverPoolManager(owner).feeTo();
        globalState.protocolFees.token0 = 0;
        globalState.protocolFees.token1 = 0;
        SafeTransfers.transferOut(feeTo, token0, token0Fees);
        SafeTransfers.transferOut(feeTo, token1, token1Fees);
    }

    function _immutables() private view returns (
        Immutables memory
    ) {
        return Immutables(
            ICurveMath(curveMath),
            ITwapSource(twapSource),
            ITickMath.PriceBounds(minPrice, maxPrice),
            token0,
            token1,
            inputPool,
            minAmountPerAuction,
            genesisTime,
            minPositionWidth,
            tickSpread,
            twapLength,
            auctionLength,
            blockTime,
            token0Decimals,
            token1Decimals,
            minAmountLowerPriced
        );
    }

    function _prelock() private {
        if (globalState.unlocked == 0) {
            globalState = Ticks.initialize(tickMap, pool0, pool1, globalState, _immutables());
        }
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
    }

    function _postlock() private {
        globalState.unlocked = 1;
    }

    function _onlyOwner() private view {
        if (msg.sender != owner) revert OwnerOnly();
    }
}
