// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/IRangePool.sol';
import './interfaces/ICoverPoolManager.sol';
import './base/modifiers/CoverPoolModifiers.sol';
import './base/events/CoverPoolEvents.sol';
import './utils/SafeTransfers.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Ticks.sol';
import './libraries/Positions.sol';
import './libraries/Epochs.sol';

/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolEvents,
    CoverPoolModifiers,
    SafeTransfers
{
    address public immutable factory;
    address internal immutable token0;
    address internal immutable token1;

    constructor(
        address _inputPool,
        int16   _tickSpread,
        uint16  _twapLength,
        uint16  _auctionLength
    ) {
        // set addresses
        factory   = msg.sender;
        token0    = IRangePool(_inputPool).token0();
        token1    = IRangePool(_inputPool).token1();

        // set global state
        GlobalState memory state;
        state.tickSpread    = _tickSpread;
        state.twapLength    = _twapLength;
        state.auctionLength = _auctionLength;
        state.genesisBlock  = uint32(block.number);
        state.inputPool     = IRangePool(_inputPool);
        state.protocolFees  = ProtocolFees(0,0);

        // set initial ticks
        state = Ticks.initialize(
            tickMap,
            pool0,
            pool1,
            state
        );

        globalState = state;
    }

    function mint(
        MintParams memory params
    ) external lock {
        GlobalState memory state = globalState;
        (state, pool0, pool1) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state
        );
        uint256 liquidityMinted;
        (params, liquidityMinted) = Positions.validate(params, state);

        if (params.zeroForOne) {
            _transferIn(token0, params.amount);
        } else {
            _transferIn(token1, params.amount);
        }
        // recreates position if required
        state = Positions.update(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickMap,
            state,
            params.zeroForOne ? pool0 : pool1,
            UpdateParams(
                params.to,
                params.lower,
                params.upper,
                params.claim,
                params.zeroForOne,
                0
            )
        );
        Positions.add(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickMap,
            state,
            AddParams(
                params.to,
                params.lower,
                params.upper,
                params.zeroForOne,
                uint128(liquidityMinted)
            )
        );
        emit Mint(
            params.to,
            params.lower,
            params.upper,
            params.claim,
            params.zeroForOne,
            uint128(liquidityMinted)
        );
        globalState = state;
    }

    function burn(
        BurnParams memory params
    ) external lock {
        GlobalState memory state = globalState;
        (state, pool0, pool1) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state
        );
        Position memory position = params.zeroForOne ? positions0[msg.sender][params.lower][params.upper]
                                                     : positions1[msg.sender][params.lower][params.upper];
        if (position.claimPriceLast > 0
            || params.claim != (params.zeroForOne ? params.upper : params.lower) 
            || params.claim == state.latestTick)
        {
            // if position has been crossed into
            state = Positions.update(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                state,
                params.zeroForOne ? pool0 : pool1,
                UpdateParams(
                    msg.sender,
                    params.lower,
                    params.upper,
                    params.claim,
                    params.zeroForOne,
                    params.amount
                )
            );
        } else {
            // if position hasn't been crossed into
            (, state) = Positions.remove(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickMap,
                state,
                RemoveParams(msg.sender, params.lower, params.upper, params.zeroForOne, params.amount)
            );
        }
        // emit Burn(msg.sender, params.lower, params.upper, params.claim, params.zeroForOne, params.amount);
        // force collection
        if (params.collect) {
             mapping(address => mapping(int24 => mapping(int24 => Position))) storage positions = params.zeroForOne ? positions0 : positions1;
            params.zeroForOne ? params.upper = params.claim : params.lower = params.claim;

            // store amounts for transferOut
            uint128 amountIn = positions[msg.sender][params.lower][params.upper].amountIn;
            uint128 amountOut = positions[msg.sender][params.lower][params.upper].amountOut;

            // console.log('amountIn:', amountIn);
            // console.log(params.zeroForOne ? ERC20(token1).balanceOf(address(this)) : ERC20(token0).balanceOf(address(this)));
            // console.log('amountOut:', amountOut);
            // console.log(params.zeroForOne ? ERC20(token0).balanceOf(address(this)) : ERC20(token1).balanceOf(address(this)));

            // zero out balances
            positions[msg.sender][params.lower][params.upper].amountIn = 0;
            positions[msg.sender][params.lower][params.upper].amountOut = 0;

            /// transfer out balances
            // transfer out to params.to
            _transferOut(msg.sender, params.zeroForOne ? token1 : token0, amountIn);
            _transferOut(msg.sender, params.zeroForOne ? token0 : token1, amountOut);

            emit Collect(msg.sender, amountIn, amountOut);
        }
        globalState = state;
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
        TickMath.validatePrice(priceLimit);
        (state, pool0, pool1) = Epochs.syncLatest(
            ticks0,
            ticks1,
            tickMap,
            pool0,
            pool1,
            state
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
            auctionDepth: block.number - state.genesisBlock - state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            inputBoosted: 0,
            amountInDelta: 0
        });
        /// @dev - liquidity range is limited to one tick
        (cache, amountOut) = Ticks.quote(zeroForOne, priceLimit, state, cache);

        if (zeroForOne) {
            pool1.price = uint160(cache.price);
            pool1.amountInDelta += uint128(cache.amountInDelta);
        } else {
            pool0.price = uint160(cache.price);
            pool0.amountInDelta += uint128(cache.amountInDelta);
        }

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
        globalState = state;
    }

    //TODO: handle quoteAmountIn and quoteAmountOut
    function quote(
        bool zeroForOne,
        uint256 amountIn,
        uint160 priceLimit
    ) external view returns (uint256 inAmount, uint256 outAmount) {
        // TODO: make override
        GlobalState memory state = globalState;
        SwapCache memory cache = SwapCache({
            price: zeroForOne ? pool1.price : pool0.price,
            liquidity: zeroForOne ? pool1.liquidity : pool0.liquidity,
            amountIn: amountIn,
            auctionDepth: block.number - state.genesisBlock - state.auctionStart,
            auctionBoost: 0,
            input: amountIn,
            inputBoosted: 0,
            amountInDelta: 0
        });
        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        (cache, outAmount) = Ticks.quote(zeroForOne, priceLimit, state, cache);
        inAmount = amountIn - cache.input;

        return (inAmount, outAmount);
    }

    function collectFees() public returns (uint128 token0Fees, uint128 token1Fees) {
        token0Fees = globalState.protocolFees.token0;
        token1Fees = globalState.protocolFees.token1;
        address feeTo = ICoverPoolManager(ICoverPoolFactory(factory).owner()).feeTo();
        _transferOut(feeTo, token0, token0Fees);
        _transferOut(feeTo, token1, token1Fees);
        globalState.protocolFees.token0 = 0;
        globalState.protocolFees.token1 = 0;
    }

    //TODO: zap into LP position
    //TODO: use bitmaps to naiively search for the tick closest to the new TWAP
    //TODO: assume everything will get filled for now
    //TODO: remove old latest tick if necessary
    //TODO: after accumulation, all liquidity below old latest tick is removed
    //TODO: don't update state.latestTick until TWAP has moved +/- tickSpacing
    //TODO: state.latestTick needs to be a multiple of tickSpacing
    //TODO: consider partial fills and how that impacts claims
    //TODO: consider current price...we might have to skip claims/burns from current tick
}
