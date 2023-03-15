// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/IRangePool.sol';
import './base/CoverPoolStorage.sol';
import './base/CoverPoolEvents.sol';
import './utils/SafeTransfers.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Ticks.sol';
import './libraries/Positions.sol';
import './libraries/Epochs.sol';

/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolStorage,
    CoverPoolEvents,
    CoverTicksErrors,
    CoverMiscErrors,
    CoverPositionErrors,
    SafeTransfers
{
    address internal immutable factory;
    address internal immutable token0;
    address internal immutable token1;

    modifier lock() {
        if (globalState.unlocked == 0) {
            globalState = Ticks.initialize(tickNodes, pool0, pool1, globalState);
        }
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
        _;
        globalState.unlocked = 1;
    }

    constructor(
        address _inputPool,
        int16 _tickSpread,
        uint16 _twapLength,
        uint16 _auctionLength
    ) {
        // set addresses
        factory   = msg.sender;
        token0    = IRangePool(_inputPool).token0();
        token1    = IRangePool(_inputPool).token1();
        feeTo     = ICoverPoolFactory(msg.sender).owner();

        // set global state
        GlobalState memory state;
        state.tickSpread    = _tickSpread;
        state.twapLength    = _twapLength;
        state.auctionLength = _auctionLength;
        state.genesisBlock  = uint32(block.number);
        state.inputPool     = IRangePool(_inputPool);

        // set initial ticks
        state = Ticks.initialize(
            tickNodes,
            pool0,
            pool1,
            state
        );

        globalState = state;
    }

    function mint(
        MintParams calldata mintParams
    ) external lock {
        MintParams memory params = mintParams;
        GlobalState memory state = globalState;
        if (block.number != globalState.lastBlock) {
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state
            );
        }
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
            tickNodes,
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
        (, state) = Positions.add(
            params.zeroForOne ? positions0 : positions1,
            params.zeroForOne ? ticks0 : ticks1,
            tickNodes,
            state,
            AddParams(
                params.to,
                params.lowerOld,
                params.lower,
                params.upper,
                params.upperOld,
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
        BurnParams calldata burnParams
    ) external lock {
        BurnParams memory params = burnParams;
        GlobalState memory state = globalState;
        if (block.number != state.lastBlock) {
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state
            );
        }
        if (params.claim != (params.zeroForOne ? params.upper : params.lower) 
                         || params.claim == state.latestTick)
        {
            // if position has been crossed into
            state = Positions.update(
                params.zeroForOne ? positions0 : positions1,
                params.zeroForOne ? ticks0 : ticks1,
                tickNodes,
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
                tickNodes,
                state,
                RemoveParams(msg.sender, params.lower, params.upper, params.zeroForOne, params.amount)
            );
        }
        emit Burn(msg.sender, params.lower, params.upper, params.claim, params.zeroForOne, params.amount);
        if (params.collect) {
             mapping(address => mapping(int24 => mapping(int24 => Position))) storage positions = params.zeroForOne ? positions0 : positions1;
            params.zeroForOne ? params.upper = params.claim : params.lower = params.claim;

            // store amounts for transferOut
            uint128 amountIn = positions[msg.sender][params.lower][params.upper].amountIn;
            uint128 amountOut = positions[msg.sender][params.lower][params.upper].amountOut;

            console.log('amountIn:', amountIn);
            console.log(params.zeroForOne ? ERC20(token1).balanceOf(address(this)) : ERC20(token0).balanceOf(address(this)));
            console.log('amountOut:', amountOut);
            console.log(params.zeroForOne ? ERC20(token0).balanceOf(address(this)) : ERC20(token1).balanceOf(address(this)));

            // zero out balances
            positions[msg.sender][params.lower][params.upper].amountIn = 0;
            positions[msg.sender][params.lower][params.upper].amountOut = 0;

            /// transfer out balances
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
        PoolState memory pool = zeroForOne ? pool1 : pool0;
        TickMath.validatePrice(priceLimit);
        if (block.number != state.lastBlock) {
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state
            );
        }
        if (amountIn == 0) {
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
