// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/ICoverPoolManager.sol';
import './base/events/CoverPoolEvents.sol';
import './base/storage/CoverPoolStorage.sol';
import './base/structs/CoverPoolFactoryStructs.sol';
import './utils/SafeTransfers.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Positions.sol';
import './libraries/Epochs.sol';

/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolEvents,
    CoverPoolFactoryStructs,
    CoverPoolStorage,
    SafeTransfers
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
    ) external lock {
        MintCache memory cache = MintCache({
            state: globalState,
            position: params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                        : positions1[msg.sender][params.lower][params.upper],
            constants: _immutables(),
            syncFees: SyncFees(0,0),
            liquidityMinted: 0
        });
        (
            cache.state,
            cache.syncFees,
            pool0, 
            pool1
        ) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            cache.state,
            cache.constants
        );
        // resize position if necessary
        (params, cache.liquidityMinted) = Positions.resize(
            cache.position,
            params, 
            cache.state,
            cache.constants
        );
        // params.amount must be > 0 here
        _transferIn(params.zeroForOne ? token0 : token1, params.amount);
        // recreates position if required
        (cache.state,) = Positions.update(
            params.zeroForOne ? positions0 : positions1, //TODO: start and end; one mapping
            params.zeroForOne ? ticks0 : ticks1, //TODO: mappings of mappings; pass params.zeroForOne
            tickMap,
            cache.state,
            params.zeroForOne ? pool0 : pool1, //TODO: mapping and pass params.zeroForOne
            UpdateParams(
                msg.sender,
                params.to,
                0,
                params.lower,
                params.upper,
                params.claim,
                params.zeroForOne
            ),
            cache.constants
        );
        cache.state = Positions.add(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickMap,
            cache.state,
            AddParams(
                params.to,
                uint128(cache.liquidityMinted),
                params.amount,
                params.lower,
                params.claim,
                params.upper,
                params.zeroForOne
            ),
            _immutables()
        );
        globalState = cache.state;
        _collect(
            CollectParams(
                cache.syncFees,
                params.to, //address(0) goes to msg.sender
                params.lower,
                params.claim,
                params.upper,
                params.zeroForOne
            )
        );
    }

    function burn(
        BurnParams memory params
    ) external lock {
        if (params.to == address(0)) revert CollectToZeroAddress();
        BurnCache memory cache = BurnCache({
            state: globalState,
            position: params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                        : positions1[msg.sender][params.lower][params.upper],
            constants: _immutables(),
            syncFees: SyncFees(0,0)
        });
        if (params.sync)
            (cache.state, cache.syncFees, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickMap,
                pool0,
                pool1,
                cache.state,
                cache.constants
        );
        if (cache.position.claimPriceLast > 0
            || params.claim != (params.zeroForOne ? params.upper : params.lower) 
            || params.claim == cache.state.latestTick)
        {
            // if position has been crossed into
            (cache.state, params.claim) = Positions.update(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                cache.state,
                params.zeroForOne ? pool0 : pool1,
                UpdateParams(
                    msg.sender,
                    params.to,
                    params.burnPercent,
                    params.lower,
                    params.upper,
                    params.claim,
                    params.zeroForOne
                ),
                _immutables()
            );
        } else {
            // if position hasn't been crossed into
            (, cache.state) = Positions.remove(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                cache.state,
                RemoveParams(
                    msg.sender,
                    params.to,
                    params.burnPercent,
                    params.lower,
                    params.upper,
                    params.zeroForOne
                ),
                _immutables()
            );
        }
        globalState = cache.state;
        _collect(
            CollectParams(
                cache.syncFees,
                params.to, //address(0) goes to msg.sender
                params.lower,
                params.claim,
                params.upper,
                params.zeroForOne
            )
        );
    }

    function swap(
        address recipient,
        bool zeroForOne,
        uint128 amountIn,
        uint160 priceLimit
    ) external override lock returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    ) 
    {
        ICurveMath(curveMath).checkPrice(
            priceLimit,
            ITickMath.PriceBounds(minPrice, maxPrice));
        SwapCache memory cache;
        cache.state = globalState;
        cache.constants = _immutables();
        (
            cache.state,
            cache.syncFees,
            pool0,
            pool1
        ) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            cache.state,
            _immutables()
        );
        PoolState memory pool = zeroForOne ? pool1 : pool0;
        cache = SwapCache({
            state: cache.state,
            syncFees: cache.syncFees,
            constants: cache.constants,
            price: pool.price,
            liquidity: pool.liquidity,
            amountIn: amountIn,
            auctionDepth: block.timestamp - genesisTime - cache.state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            output: 0,
            inputBoosted: 0,
            amountInDelta: 0
        });

        _transferIn(zeroForOne ? token0 : token1, amountIn);

        /// @dev - liquidity range is limited to one tick
        cache = Ticks.quote(zeroForOne, priceLimit, cache.state, cache, _immutables());

        if (zeroForOne) {
            pool1.price = uint160(cache.price);
            pool1.amountInDelta += uint128(cache.amountInDelta);
        } else {
            pool0.price = uint160(cache.price);
            pool0.amountInDelta += uint128(cache.amountInDelta);
        }

        globalState = cache.state;

        if (zeroForOne) {
            if (cache.input + cache.syncFees.token0 > 0) {
                _transferOut(recipient, token0, cache.input + cache.syncFees.token0);
            }
            if (cache.output + cache.syncFees.token1 > 0) {
                _transferOut(recipient, token1, cache.output + cache.syncFees.token1);
                emit Swap(recipient, uint128(amountIn - cache.input), uint128(cache.output), uint160(cache.price), priceLimit, zeroForOne);
            }
            return (
                int128(amountIn) - int256(cache.input) - int128(cache.syncFees.token0),
                cache.output + cache.syncFees.token1,
                cache.price 
            );
        } else {
            if (cache.input + cache.syncFees.token1 > 0) {
                _transferOut(recipient, token1, cache.input + cache.syncFees.token1);
            }
            if (cache.output + cache.syncFees.token0 > 0) {
                _transferOut(recipient, token0, cache.output + cache.syncFees.token0);
                emit Swap(recipient, uint128(amountIn - cache.input), uint128(cache.output), uint160(cache.price), priceLimit, zeroForOne);
            }
            return (
                int128(amountIn) - int256(cache.input) - int128(cache.syncFees.token1),
                cache.output + cache.syncFees.token0,
                cache.price 
            );
        }
    }

    function quote(
        bool zeroForOne,
        uint128 amountIn,
        uint160 priceLimit
    ) external view override returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    ) {
        PoolState memory pool0State;
        PoolState memory pool1State;
        SwapCache memory cache;
        cache.state = globalState;
        cache.constants = _immutables();
        (
            cache.state,
            cache.syncFees,
            pool0State,
            pool1State
        ) = Epochs.simulateSync(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            cache.state,
            cache.constants
        );
        cache = SwapCache({
            state: cache.state,
            syncFees: cache.syncFees,
            constants: cache.constants,
            price: zeroForOne ? pool1State.price : pool0State.price,
            liquidity: zeroForOne ? pool1State.liquidity : pool0State.liquidity,
            amountIn: amountIn,
            auctionDepth: block.timestamp - genesisTime - cache.state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            output: 0,
            inputBoosted: 0,
            amountInDelta: 0
        });
        cache = Ticks.quote(zeroForOne, priceLimit, cache.state, cache, _immutables());
        if (zeroForOne) {
            return (
                int128(amountIn) - int256(cache.input) - int128(cache.syncFees.token0),
                cache.output + cache.syncFees.token1,
                cache.price 
            );
        } else {
            return (
                int128(amountIn) - int256(cache.input) - int128(cache.syncFees.token1),
                cache.output + cache.syncFees.token0,
                cache.price 
            );
        }
    }

    function snapshot(
       SnapshotParams memory params 
    ) external view returns (
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

    function protocolFees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external ownerOnly returns (
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
        _transferOut(feeTo, token0, token0Fees);
        _transferOut(feeTo, token1, token1Fees);
    }

    function _collect(
        CollectParams memory params
    ) internal {
        mapping(address => mapping(int24 => mapping(int24 => Position))) storage positions = params.zeroForOne ? positions0 : positions1;
        params.zeroForOne ? params.upper = params.claim : params.lower = params.claim;

        // store amounts for transferOut
        uint128 amountIn  = positions[msg.sender][params.lower][params.upper].amountIn;
        uint128 amountOut = positions[msg.sender][params.lower][params.upper].amountOut;

        // factor in sync fees
        if (params.zeroForOne) {
            amountIn  += params.syncFees.token1;
            amountOut += params.syncFees.token0;
        } else {
            amountIn  += params.syncFees.token0;
            amountOut += params.syncFees.token1;
        }

        /// zero out balances and transfer out
        if (amountIn > 0) {
            positions[msg.sender][params.lower][params.upper].amountIn = 0;
            _transferOut(params.to, params.zeroForOne ? token1 : token0, amountIn);
        } 
        if (amountOut > 0) {
            positions[msg.sender][params.lower][params.upper].amountOut = 0;
            _transferOut(params.to, params.zeroForOne ? token0 : token1, amountOut);
        }
    }

    function _immutables() private view returns (
        Immutables memory
    ) {
        return Immutables(
            ICurveMath(curveMath),
            ITwapSource(twapSource),
            ITickMath.PriceBounds(minPrice, maxPrice),
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
