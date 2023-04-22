// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/IRangePool.sol';
import './interfaces/ICoverPoolManager.sol';
import './base/events/CoverPoolEvents.sol';
import './base/structs/CoverPoolFactoryStructs.sol';
import './base/modifiers/CoverPoolModifiers.sol';
import './utils/SafeTransfers.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Positions.sol';
import './libraries/Epochs.sol';

/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolEvents,
    CoverPoolFactoryStructs,
    CoverPoolModifiers,
    SafeTransfers
{
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    address public immutable inputPool; 
    uint160 public immutable MIN_PRICE;
    uint160 public immutable MAX_PRICE;
    uint128 public immutable minAmountPerAuction;
    uint32  public immutable genesisTime;
    int16   public immutable minPositionWidth;
    int16   public immutable tickSpread;
    uint16  public immutable twapLength;
    uint16  public immutable auctionLength;
    uint16  public immutable blockTime;
    uint8   internal immutable token0Decimals;
    uint8   internal immutable token1Decimals;
    bool    public immutable minLowerPricedToken;

    error PriceOutOfBounds();

    modifier lock() {
        if (globalState.unlocked == 0) {
            globalState = Ticks.initialize(tickMap, pool0, pool1, globalState, _immutables());
        }
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
        _;
        globalState.unlocked = 1;
    }

    constructor(
        CoverPoolParams memory params
    ) {
        // set addresses
        factory   = msg.sender;
        inputPool = params.inputPool;
        token0    = IRangePool(inputPool).token0();
        token1    = IRangePool(inputPool).token1();
        
        // set token decimals
        token0Decimals = ERC20(token0).decimals();
        token1Decimals = ERC20(token1).decimals();
        if (token0Decimals > 18 || token1Decimals > 18
          || token0Decimals < 6 || token1Decimals < 6) {
            revert InvalidTokenDecimals();
        }

        // set other immutables
        auctionLength = params.auctionLength;
        blockTime = params.blockTime;
        minPositionWidth = params.minPositionWidth;
        tickSpread    = params.tickSpread;
        twapLength    = params.twapLength;
        genesisTime   = uint32(block.timestamp);
        minAmountPerAuction = params.minAmountPerAuction;
        minLowerPricedToken = params.minLowerPricedToken;

        // set price boundaries
        MIN_PRICE = TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK / tickSpread * tickSpread);
        MAX_PRICE = TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK / tickSpread * tickSpread);
    }

    function mint(
        MintParams memory params
    ) external lock {
        GlobalState memory state = globalState;
        Position memory position = params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                                     : positions1[msg.sender][params.lower][params.upper];
        (state, pool0, pool1) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state,
            _immutables()
        );
        uint256 liquidityMinted;
        // resize position if necessary
        (params, liquidityMinted) = Positions.resize(
            position,
            params, 
            state,
            _immutables()
        );

        if (params.amount > 0)
            _transferIn(params.zeroForOne ? token0 : token1, params.amount);
        // recreates position if required
        (state,) = Positions.update(
            params.zeroForOne ? positions0 : positions1, //TODO: start and end; one mapping
            params.zeroForOne ? ticks0 : ticks1, //TODO: mappings of mappings; pass params.zeroForOne
            tickMap, //TODO: merge epoch and tick map
            state,
            params.zeroForOne ? pool0 : pool1, //TODO: mapping and pass params.zeroForOne
            UpdateParams(
                msg.sender,
                0,
                params.lower,
                params.upper,
                params.claim,
                params.zeroForOne
            ),
            _immutables()
        );
        if (params.amount > 0) {
            state = Positions.add(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                state,
                AddParams(
                    params.to,
                    uint128(liquidityMinted),
                    params.lower,
                    params.claim,
                    params.upper,
                    params.zeroForOne
                ),
                tickSpread
            );
        }
        globalState = state;
        _collect(
            CollectParams(
                params.to, //address(0) goes to msg.sender
                0,
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
        GlobalState memory state = globalState;
        if (params.sync)
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickMap,
                pool0,
                pool1,
                state,
                _immutables()
            );
        Position memory position = params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                                     : positions1[msg.sender][params.lower][params.upper];
        if (position.claimPriceLast > 0
            || params.claim != (params.zeroForOne ? params.upper : params.lower) 
            || params.claim == state.latestTick)
        {
            // if position has been crossed into
            (state, params.claim) = Positions.update(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                state,
                params.zeroForOne ? pool0 : pool1,
                UpdateParams(
                    msg.sender,
                    params.amount,
                    params.lower,
                    params.upper,
                    params.claim,
                    params.zeroForOne
                ),
                _immutables()
            );
        } else {
            // if position hasn't been crossed into
            (, state) = Positions.remove(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                state,
                RemoveParams(
                    msg.sender,
                    params.amount,
                    params.lower,
                    params.upper,
                    params.zeroForOne
                ),
                _immutables()
            );
        }
        globalState = state;
        _collect(
            CollectParams(
                params.to, //address(0) goes to msg.sender
                params.amount,
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
    )
        external
        override
        lock
        returns (uint256 amountOut)
    {
        GlobalState memory state = globalState;
        _validatePrice(priceLimit);
        (state, pool0, pool1) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state,
            _immutables()
        );
        PoolState memory pool = zeroForOne ? pool1 : pool0;
        if (amountIn == 0) {
            // transfer out syncing fee here
            globalState = state;
            return 0;
        }

        _transferIn(zeroForOne ? token0 : token1, amountIn);

        SwapCache memory cache = SwapCache({
            price: pool.price,
            liquidity: pool.liquidity,
            amountIn: amountIn,
            auctionDepth: block.timestamp - genesisTime - state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            inputBoosted: 0,
            amountInDelta: 0
        });
        /// @dev - liquidity range is limited to one tick
        (cache, amountOut) = Ticks.quote(zeroForOne, priceLimit, state, cache, _immutables());

        if (zeroForOne) {
            pool1.price = uint160(cache.price);
            pool1.amountInDelta += uint128(cache.amountInDelta);
        } else {
            pool0.price = uint160(cache.price);
            pool0.amountInDelta += uint128(cache.amountInDelta);
        }

        globalState = state;

        if (zeroForOne) {
            if (cache.input > 0) {
                _transferOut(recipient, token0, cache.input);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token0, token1, amountIn - cache.input, amountOut);
        } else {
            if (cache.input > 0) {
                _transferOut(recipient, token1, cache.input);
            }
            _transferOut(recipient, token0, amountOut);
            emit Swap(recipient, token1, token0, amountIn - cache.input, amountOut);
        }
    }

    function quote(
        bool zeroForOne,
        uint128 amountIn,
        uint160 priceLimit
    ) external view override returns (
        uint256 inAmount,
        uint256 outAmount
    ) {
        GlobalState memory state = globalState;
        PoolState memory pool0State;
        PoolState memory pool1State;
        (state, pool0State, pool1State) = Epochs.simulateSync(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state,
            _immutables()
        );
        SwapCache memory cache = SwapCache({
            price: zeroForOne ? pool1State.price : pool0State.price,
            liquidity: zeroForOne ? pool1State.liquidity : pool0State.liquidity,
            amountIn: amountIn,
            auctionDepth: block.timestamp - genesisTime - state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            inputBoosted: 0,
            amountInDelta: 0
        });
        (cache, outAmount) = Ticks.quote(zeroForOne, priceLimit, state, cache, _immutables());
        inAmount = amountIn - cache.input;

        return (inAmount, outAmount);
    }

    function snapshot(
       UpdateParams memory params 
    ) external view returns (
        Position memory
    ) {
        return Positions.snapshot(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickMap,
            globalState,
            params.zeroForOne ? pool0 : pool1,
            params,
            _immutables()
        );
    }

    function collectFees() public returns (
        uint128 token0Fees,
        uint128 token1Fees
    ) {
        token0Fees = globalState.protocolFees.token0;
        token1Fees = globalState.protocolFees.token1;
        address feeTo = ICoverPoolManager(ICoverPoolFactory(factory).owner()).feeTo();
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

        /// zero out balances and transfer out
        if (amountIn > 0) {
            positions[msg.sender][params.lower][params.upper].amountIn = 0;
            _transferOut(params.to, params.zeroForOne ? token1 : token0, amountIn);
        } 
        if (amountOut > 0) {
            positions[msg.sender][params.lower][params.upper].amountOut = 0;
            _transferOut(params.to, params.zeroForOne ? token0 : token1, amountOut);
        } 

        // emit event
        if (amountIn > 0 || amountOut > 0)
            emit Burn(msg.sender, params.to, params.lower, params.upper, params.claim, params.zeroForOne, params.amount);
    }

    function _immutables() internal view returns (
        Immutables memory
    ) {
        return Immutables(
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
            minLowerPricedToken
        );
    }

    function _validatePrice(uint160 price) internal view {
        if (price < MIN_PRICE || price >= MAX_PRICE) {
            revert PriceOutOfBounds();
        }
    }

    //TODO: zap into LP position
    //TODO: remove old latest tick if necessary
}
