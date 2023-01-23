// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

//TODO: deploy library code once and reference from factory
// have interfaces for library contracts
import "./interfaces/ICoverPool.sol";
import "./interfaces/IRangePool.sol";
import "./base/CoverPoolStorage.sol";
import "./base/CoverPoolEvents.sol";
import "./utils/SafeTransfers.sol";
import "./utils/CoverPoolErrors.sol";
import "./libraries/Ticks.sol";
import "./libraries/Positions.sol";
import "hardhat/console.sol";

/// @notice Poolshark Directional Liquidity pool implementation.
/// @dev SafeTransfers contains CoverPoolErrors
contract CoverPool is
    ICoverPool,
    CoverPoolStorage,
    CoverPoolEvents,
    CoverTicksErrors,
    CoverMiscErrors,
    CoverPositionErrors,
    SafeTransfers
{
    /// @dev Reference: tickSpacing of 100 -> 1% between ticks.
    uint128 internal immutable MAX_TICK_LIQUIDITY;

    address internal immutable factory;
    address internal immutable token0;
    address internal immutable token1;

    IRangePool internal immutable inputPool;

    modifier lock() {
        if (globalState.unlocked != 1) revert Locked();
        globalState.unlocked = 2;
        _;
        globalState.unlocked = 1;
    }

    constructor(
        address _inputPool,
        address _libraries,
        uint24  _swapFee, 
        int24  _tickSpread
    ) {
        // validate swap fee
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();
        GlobalState memory state = GlobalState(0,0,0,0,0,0);
        // validate tick spread
        int24 _tickSpacing = IRangePool(_inputPool).tickSpacing();
        int24 _tickMultiple = _tickSpread / _tickSpacing;
        if ((_tickMultiple < 2) 
          || _tickMultiple * _tickSpacing != _tickSpread
        ) revert InvalidTickSpread();

        // set addresses
        factory     = msg.sender;
        utils       = IPoolsharkUtils(_libraries);
        token0      = IRangePool(_inputPool).token0();
        token1      = IRangePool(_inputPool).token1();
        inputPool   = IRangePool(_inputPool);
        feeTo       = ICoverPoolFactory(msg.sender).owner();

        // set global state
        state.swapFee         = _swapFee;
        state.tickSpread      = _tickSpread;
        state.lastBlockNumber = uint32(block.number);
        globalState = state;

        // set max liquidity per tick
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpread);

        // set default initial values
        //TODO: insertSingle or pass MAX_TICK as upper
        _ensureInitialized();
    }

    //TODO: test this check
    function _ensureInitialized() internal {
        if (globalState.unlocked == 0) {
            GlobalState memory state = globalState;
            (state.unlocked, state.latestTick) = utils.initializePoolObservations(
                                                    IRangePool(inputPool)
                                                );
            if(state.unlocked == 1) { _initialize(state); }
        }
    }

    function _initialize(GlobalState memory state) internal {
        //TODO: store values in memory then write to state
        state.latestTick = state.latestTick / int24(state.tickSpread) * int24(state.tickSpread);
        state.accumEpoch = 1;
        Ticks.initialize(
            tickNodes,
            pool0,
            pool1,
            state.latestTick,
            state.accumEpoch,
            state.tickSpread
        );
        globalState = state;
    }
    //TODO: create transfer function to transfer ownership
    //TODO: reorder params to upperOld being last (logical order)

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        int24 claim,
        uint128 amountDesired,
        bool zeroForOne
    ) external lock {
        /// @dev - don't allow mints until we have enough observations from inputPool
        _ensureInitialized();
        // GlobalState memory globalState = globalState;
        if (globalState.unlocked == 0 ) revert WaitUntilEnoughObservations();
        
        //TODO: move tick update check here
        if(block.number != globalState.lastBlockNumber) {
            globalState.lastBlockNumber = uint32(block.number);
            //can save a couple 100 gas if we skip this when no update
            (globalState, pool0, pool1) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                globalState,
                utils.calculateAverageTick(inputPool)
            );
        }
        uint256 liquidityMinted;
        (
            lowerOld,
            lower,
            upper,
            upperOld,
            amountDesired,
            liquidityMinted
        ) = Positions.validate(
            ValidateParams(
                lowerOld,
                lower,
                upper,
                upperOld,
                zeroForOne,
                amountDesired,
                globalState
            )
        );
        //TODO: handle upperOld and lowerOld being invalid

        if(zeroForOne){
            _transferIn(token0, amountDesired);
        } else {
            _transferIn(token1, amountDesired);
        }
        //TODO: is this dangerous?
        unchecked {
            // recreates position if required
            (,,,,globalState) = Positions.update(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                globalState,
                zeroForOne ? pool0 : pool1,
                UpdateParams(
                    msg.sender,
                    lower,
                    upper,
                    claim,
                    zeroForOne,
                    0
                )
            );

            //TODO: check amount consumed from return value
            // creates new position
            (,globalState) = Positions.add(
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
        console.logInt(ticks1[lower].liquidityDelta);
        emit Mint(
            msg.sender,
            lower,
            upper,
            zeroForOne,
            uint128(liquidityMinted)
        );
        // globalState = state;
    }

    function burn(
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne,
        uint128 amount
    )
        public
        lock
    {
        GlobalState memory state = globalState;
        if(block.number != state.lastBlockNumber) {
            // console.log("accumulating last block");
            state.lastBlockNumber = uint32(block.number);
            (
                state,
                pool0, 
                pool1
            ) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state,
                utils.calculateAverageTick(inputPool)
            );
        }
        console.log('zero previous tick:');
        console.log('zero previus tick:');
        // console.logInt(ticks[0].previousTick);

        //TODO: burning liquidity should take liquidity out past the current auction
        
        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();

        // update position and get new lower and upper
        (,,lower,upper, state) = Positions.update(
            zeroForOne ? positions0 : positions1,
            zeroForOne ? ticks0 : ticks1,
            tickNodes,
            state,
            zeroForOne ? pool0 : pool1,
            UpdateParams(
                msg.sender,
                lower,
                upper,
                claim,
                zeroForOne,
                int128(amount)
            )
        );
        console.logInt(claim);
        console.logInt(lower);
        // if position hasn't changed remove liquidity
        if (claim == (zeroForOne ? upper : lower)) {
            console.log('removing liquidity');
            (,state) = Positions.remove(
               zeroForOne ? positions0 : positions1,
               zeroForOne ? ticks0 : ticks1,
               tickNodes,
               state,
               RemoveParams(
                msg.sender,
                lower,
                upper,
                zeroForOne,
                amount
               )
            );
        }

        console.log('zero previous tick:');
        //TODO: get token amounts from _updatePosition return values
        emit Burn(msg.sender, lower, upper, zeroForOne, amount);
        globalState = state;
    }

    function collect(
        int24 lower,
        int24 upper,
        int24 claim,
        bool  zeroForOne
    ) public lock returns (uint256 amountIn, uint256 amountOut) {
        GlobalState memory state = globalState;
        if(block.number != state.lastBlockNumber) {
            // console.log("accumulating last block");
            state.lastBlockNumber = uint32(block.number);
            (
                state,
                pool0, 
                pool1
            ) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state,
                utils.calculateAverageTick(inputPool)
            );
        }
        (amountIn,amountOut,,,state) = Positions.update(
            zeroForOne ? positions0 : positions1,
            zeroForOne ? ticks0 : ticks1,
            tickNodes,
            state,
            zeroForOne ? pool0 : pool1,
            UpdateParams(
                msg.sender,
                lower,
                upper,
                claim,
                zeroForOne,
                0
            )
        );
        console.log(positions1[msg.sender][lower][upper].amountOut);
        /// zero out balances
        zeroForOne ? positions0[msg.sender][lower][upper].amountIn = 0 
                   : positions1[msg.sender][lower][upper].amountIn = 0;
        zeroForOne ? positions0[msg.sender][lower][upper].amountOut = 0 
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
        // bytes calldata data
    ) external override lock returns (uint256 amountOut) {
        //TODO: is this needed?
        GlobalState memory state = globalState;
        if (state.latestTick < TickMath.MIN_TICK) revert WaitUntilEnoughObservations();
        PoolState   memory pool  = zeroForOne ? pool1 : pool0;
        TickMath.validatePrice(priceLimit);

        _transferIn(zeroForOne ? token0 : token1, amountIn);

        if(block.number != state.lastBlockNumber) {
            state.lastBlockNumber = uint32(block.number);
            // console.log('min latest max');
            // console.logInt(tickNodes[-887272].nextTick);
            // console.logInt(tickNodes[-887272].previousTick);
            (state, pool0, pool1) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                state,
                utils.calculateAverageTick(inputPool)
            );
        }

        SwapCache memory cache = SwapCache({
            price: pool.price,
            liquidity: pool.liquidity,
            feeAmount: utils.mulDivRoundingUp(amountIn, state.swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, state.swapFee, 1e6)
        });

        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        (
            cache,
            amountOut
        ) = Ticks.quote(
                zeroForOne,
                priceLimit,
                state,
                cache
        );

        // amountOut += output;

        zeroForOne ? pool1.price = uint160(cache.price)
                   : pool0.price = uint160(cache.price);

        if (zeroForOne) {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.feeAmount -= feeReturn;
                pool.feeGrowthCurrentEpoch += uint128(cache.feeAmount); 
                _transferOut(recipient, token0, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token0, token1, amountIn, amountOut);
        } else {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.feeAmount -= feeReturn;
                pool.feeGrowthCurrentEpoch += uint128(cache.feeAmount); 
                _transferOut(recipient, token1, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
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
            feeAmount: utils.mulDivRoundingUp(amountIn, state.swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, state.swapFee, 1e6)
        });
        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        (
            cache,
            outAmount
        ) = Ticks.quote(
                zeroForOne,
                priceLimit,
                state,
                cache
        );
        if (zeroForOne) {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.input += feeReturn;
            }
        } else {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
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
