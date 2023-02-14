// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/IRangePool.sol';
import './base/CoverPoolStorage.sol';
import './base/CoverPoolEvents.sol';
import './utils/SafeTransfers.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Ticks.sol';
import './libraries/TwapOracle.sol';
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

    IRangePool internal immutable inputPool;

    modifier lock() {
        _ensureInitialized(globalState);
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
        _;
        globalState.unlocked = 1;
    }

    constructor(
        address _inputPool,
        uint16 _swapFee,
        int16 _tickSpread,
        uint16 _twapLength,
        uint16 _auctionLength
    ) {
        // validate swap fee
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();
        // validate tick spread
        int24 _tickSpacing = IRangePool(_inputPool).tickSpacing();
        int24 _tickMultiple = _tickSpread / _tickSpacing;
        if ((_tickMultiple < 2) || _tickMultiple * _tickSpacing != _tickSpread)
            revert InvalidTickSpread();

        // set addresses
        factory   = msg.sender;
        token0    = IRangePool(_inputPool).token0();
        token1    = IRangePool(_inputPool).token1();
        inputPool = IRangePool(_inputPool);
        feeTo     = ICoverPoolFactory(msg.sender).owner();

        // set global state
        GlobalState memory state = GlobalState(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        state.swapFee       = _swapFee;
        state.tickSpread    = _tickSpread;
        state.twapLength    = _twapLength;
        state.auctionLength = _auctionLength;
        state.genesisBlock  = uint32(block.number);

        // set initial ticks
        _ensureInitialized(state);
    }

    function _ensureInitialized(GlobalState memory state) internal {
        if (state.unlocked == 0) {
            (state.unlocked, state.latestTick) = TwapOracle.initializePoolObservations(
                IRangePool(inputPool),
                state.twapLength
            );
            if (state.unlocked == 1) {
                _initialize(state);
            }
            globalState = state;
        }
    }

    function _initialize(GlobalState memory state) internal {
        state.latestTick = (state.latestTick / int24(state.tickSpread)) * int24(state.tickSpread);
        state.latestPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
        state.auctionStart = uint32(block.number - state.genesisBlock);
        state.accumEpoch = 1;
        Ticks.initialize(
            tickNodes,
            pool0,
            pool1,
            state.latestTick,
            state.accumEpoch,
            state.tickSpread
        );
    }

    //TODO: create transfer function to transfer ownership
    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(
        int24 lowerOld,
        int24 lower,
        int24 claim,
        int24 upper,
        int24 upperOld,
        uint128 amountDesired,
        bool zeroForOne
    ) external lock {
        /// @dev - don't allow mints until we have enough observations from inputPool
        //TODO: move tick update check here
        if (block.number != globalState.lastBlock) {
            //can save a couple 100 gas if we skip this when no update
            (globalState, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                globalState,
                TwapOracle.calculateAverageTick(inputPool, globalState.twapLength)
            );
        }
        uint256 liquidityMinted;
        (lowerOld, lower, upper, upperOld, amountDesired, liquidityMinted) = Positions.validate(
            ValidateParams(lowerOld, lower, upper, upperOld, zeroForOne, amountDesired, globalState)
        );
        //TODO: handle upperOld and lowerOld being invalid

        if (zeroForOne) {
            _transferIn(token0, amountDesired);
        } else {
            _transferIn(token1, amountDesired);
        }
        //TODO: is this dangerous?
        unchecked {
            // recreates position if required
            (, , , , globalState) = Positions.update(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                globalState,
                zeroForOne ? pool0 : pool1,
                UpdateParams(msg.sender, lower, upper, claim, zeroForOne, 0)
            );
            //TODO: check amount consumed from return value
            //TODO: would be nice to reject invalid claim ticks on mint
            //      don't think we can because of the 'double mint' scenario
            // creates new position
            (, globalState) = Positions.add(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                globalState,
                AddParams(
                    msg.sender,
                    lowerOld,
                    lower,
                    upper,
                    upperOld,
                    zeroForOne,
                    uint128(liquidityMinted)
                )
            );
            /// @dev - pool current liquidity should never be increased on mint
        }
        emit Mint(
            msg.sender,
            lower,
            upper,
            claim, //TODO: not sure if needed for subgraph
            zeroForOne,
            uint128(liquidityMinted)
        );
        // globalState = state;
    }

    function burn(
        int24 lower,
        int24 claim,
        int24 upper,
        bool zeroForOne,
        uint128 amount
    ) external lock {
        GlobalState memory state = globalState;
        if (block.number != state.lastBlock) {
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state,
                TwapOracle.calculateAverageTick(inputPool, state.twapLength)
            );
        }
        //TODO: burning liquidity should take liquidity out past the current auction

        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();

        if (claim != (zeroForOne ? upper : lower) || claim == state.latestTick) {
            // update position and get new lower and upper
            (, , , , state) = Positions.update(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                state,
                zeroForOne ? pool0 : pool1,
                UpdateParams(msg.sender, lower, upper, claim, zeroForOne, int128(amount))
            );
        }
        //TODO: add PositionUpdated event
        // if position hasn't changed remove liquidity
        else {
            (, state) = Positions.remove(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                state,
                RemoveParams(msg.sender, lower, upper, zeroForOne, amount)
            );
        }
        //TODO: get token amounts from _updatePosition return values
        //TODO: need to know old ticks and new ticks
        emit Burn(msg.sender, lower, upper, claim, zeroForOne, amount);
        globalState = state;
    }

    function collect(
        int24 lower,
        int24 claim,
        int24 upper,
        bool zeroForOne
    ) public lock returns (uint256 amountIn, uint256 amountOut) {
        GlobalState memory state = globalState;
        if (block.number != state.lastBlock) {
            (state, pool0, pool1) = Epochs.syncLatest(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state,
                TwapOracle.calculateAverageTick(inputPool, state.twapLength)
            );
        }
        (, , , , state) = Positions.update(
            zeroForOne ? positions0 : positions1,
            zeroForOne ? ticks0 : ticks1,
            tickNodes,
            state,
            zeroForOne ? pool0 : pool1,
            UpdateParams(msg.sender, lower, upper, claim, zeroForOne, 0)
        );
        amountIn = zeroForOne
            ? positions0[msg.sender][lower][claim].amountIn
            : positions1[msg.sender][claim][upper].amountIn;
        amountOut = zeroForOne
            ? positions0[msg.sender][lower][claim].amountOut
            : positions1[msg.sender][claim][upper].amountOut;

        /// zero out balances
        zeroForOne
            ? positions0[msg.sender][lower][claim].amountIn = 0
            : positions1[msg.sender][claim][upper].amountIn = 0;
        zeroForOne
            ? positions0[msg.sender][lower][upper].amountOut = 0
            : positions1[msg.sender][lower][upper].amountOut = 0;

        /// transfer out balances
        _transferOut(msg.sender, zeroForOne ? token1 : token0, amountIn);
        _transferOut(msg.sender, zeroForOne ? token0 : token1, amountOut);

        emit Collect(msg.sender, amountIn, amountOut);
        globalState = state;
    }

    /// @dev Swaps one token for another. The router must prefund this contract and ensure there isn't too much slippage.
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint160 priceLimit
    )
        external
        override
        // bytes calldata data
        lock
        returns (uint256 amountOut)
    {
        //TODO: is this needed?
        //TODO: implement stopPrice for pool/1
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
                state,
                TwapOracle.calculateAverageTick(inputPool, state.twapLength)
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
            feeAmount: FullPrecisionMath.mulDivRoundingUp(amountIn, state.swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn,
            amountInDelta: 0
        });

        cache.input = amountIn - cache.feeAmount;

        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        (cache, amountOut) = Ticks.quote(zeroForOne, priceLimit, state, cache);

        // amountOut += output;

        zeroForOne ? pool1.price = uint160(cache.price) : pool0.price = uint160(cache.price);

        if (zeroForOne) {
            if (cache.input > 0) {
                uint128 feeReturn = uint128(
                    (((cache.input * 1e18) / (amountIn - cache.feeAmount)) * cache.feeAmount) / 1e18
                );
                cache.feeAmount -= feeReturn;
                pool.amountInDelta += uint128(cache.feeAmount);
                _transferOut(recipient, token0, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token0, token1, amountIn, amountOut);
        } else {
            if (cache.input > 0) {
                uint128 feeReturn = uint128(
                    (((cache.input * 1e18) / (amountIn - cache.feeAmount)) * cache.feeAmount) / 1e18
                );
                cache.feeAmount -= feeReturn;
                pool.amountInDelta += uint128(cache.feeAmount);
                _transferOut(recipient, token1, cache.input + feeReturn);
            }
            _transferOut(recipient, token0, amountOut);
            emit Swap(recipient, token1, token0, amountIn, amountOut);
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
            feeAmount: FullPrecisionMath.mulDivRoundingUp(amountIn, state.swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn - FullPrecisionMath.mulDivRoundingUp(amountIn, state.swapFee, 1e6),
            amountInDelta: 0
        });
        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        (cache, outAmount) = Ticks.quote(zeroForOne, priceLimit, state, cache);
        if (zeroForOne) {
            if (cache.input > 0) {
                uint128 feeReturn = uint128(
                    (((cache.input * 1e18) / (amountIn - cache.feeAmount)) * cache.feeAmount) / 1e18
                );
                cache.input += feeReturn;
            }
        } else {
            if (cache.input > 0) {
                uint128 feeReturn = uint128(
                    (((cache.input * 1e18) / (amountIn - cache.feeAmount)) * cache.feeAmount) / 1e18
                );
                cache.input += feeReturn;
            }
        }
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

    //TODO: factor in swapFee
    //TODO: consider partial fills and how that impacts claims
    //TODO: consider current price...we might have to skip claims/burns from current tick
}
