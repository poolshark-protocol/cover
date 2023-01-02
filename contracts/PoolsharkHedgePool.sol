// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//TODO: deploy library code once and reference from factory
// have interfaces for library contracts
import "./interfaces/IPoolsharkHedgePool.sol";
import "./interfaces/IConcentratedPool.sol";
import "./base/PoolsharkHedgePoolStorage.sol";
import "./base/PoolsharkHedgePoolEvents.sol";
import "./utils/SafeTransfers.sol";
import "./utils/PoolsharkErrors.sol";
import "./libraries/Ticks.sol";
import "./libraries/Positions.sol";
import "hardhat/console.sol";

/// @notice Poolshark Directional Liquidity pool implementation.
/// @dev SafeTransfers contains PoolsharkHedgePoolErrors
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkTicksErrors,
    PoolsharkMiscErrors,
    PoolsharkPositionErrors,
    SafeTransfers
{
    /// @dev Reference: tickSpacing of 100 -> 1% between ticks.
    int24 internal immutable tickSpacing;
    uint24 internal immutable swapFee; /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
    uint128 internal immutable MAX_TICK_LIQUIDITY;

    address internal immutable factory;
    address internal immutable token0;
    address internal immutable token1;

    IConcentratedPool internal immutable inputPool;

    modifier lock() {
        if (state.unlocked != 1) revert Locked();
        state.unlocked = 2;
        _;
        state.unlocked = 1;
    }

    constructor(
        address _inputPool,
        address _libraries,
        uint24  _swapFee, 
        int24  _tickSpacing
    ) {
        // check for invalid params
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = msg.sender;
        inputPool   = IConcentratedPool(_inputPool);
        utils       = IPoolsharkUtils(_libraries);
        token0      = IConcentratedPool(inputPool).token0();
        token1      = IConcentratedPool(inputPool).token1();
        swapFee     = _swapFee;
        //TODO: should be 1% for .1% spacing on inputPool
        tickSpacing = _tickSpacing;
        state.tickSpacing = _tickSpacing;
        state.swapFee     = _swapFee;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);
        state.lastBlockNumber = uint32(block.number);

        // set default initial values
        //TODO: insertSingle or pass MAX_TICK as upper
        _ensureInitialized();
    }

    function _ensureInitialized() internal {
        if (state.unlocked == 0) {
            bool initializable; int24 initLatestTick;
            (initializable, initLatestTick) = utils.initializePoolObservations(
                                                    IConcentratedPool(inputPool)
                                                );
            if(initializable) { _initialize(initLatestTick); state.unlocked = 1; }
        }
    }

    //TODO: test this check


    function _initialize(int24 initLatestTick) internal {
        state.latestTick = initLatestTick / int24(tickSpacing) * int24(tickSpacing);
        state.accumEpoch = 1;
        state.unlocked = 1;
        Ticks.initialize(
            tickNodes,
            pool0,
            pool1,
            initLatestTick,
            state.accumEpoch
        );
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
    ) external {
        /// @dev - don't allow mints until we have enough observations from inputPool
        _ensureInitialized();
        if (state.unlocked == 0 ) revert WaitUntilEnoughObservations();
        
        //TODO: move tick update check here
        if(block.number != state.lastBlockNumber) {
            state.lastBlockNumber = uint32(block.number);
            //can save a couple 100 gas if we skip this when no update
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
        _validatePosition(lower, upper, zeroForOne, amountDesired);
        //TODO: handle upperOld and lowerOld being invalid
        uint256 liquidityMinted;
        {
            uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(lower));
            uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(upper));

            liquidityMinted = DyDxMath.getLiquidityForAmounts(
                priceLower,
                priceUpper,
                zeroForOne ? priceLower : priceUpper,
                zeroForOne ? 0 : uint256(amountDesired),
                zeroForOne ? uint256(amountDesired) : 0
            );
            // handle partial mints
            if (zeroForOne) {
                if(upper >= state.latestTick) {
                    upper = state.latestTick - int24(tickSpacing);
                    upperOld = state.latestTick;
                    uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(upper);
                    amountDesired -= uint128(DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper, false));
                    priceUpper = priceNewUpper;
                }
            }
            if (!zeroForOne) {
                if (lower <= state.latestTick) {
                    lower = state.latestTick + int24(tickSpacing);
                    lowerOld = state.latestTick;
                    uint256 priceNewLower = TickMath.getSqrtRatioAtTick(lower);
                    amountDesired -= uint128(DyDxMath.getDy(liquidityMinted, priceLower, priceNewLower, false));
                    priceLower = priceNewLower;
                }
            }
            ///TODO: check for liquidity overflow
            if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();
        }

        if(zeroForOne){
            _transferIn(token0, amountDesired);
        } else {
            _transferIn(token1, amountDesired);
        }
        //TODO: is this dangerous?
        unchecked {
            console.log('ticks before');
            console.logInt(ticks1[lower].liquidityDelta);
            // recreates position if required
            Positions.update(
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

            //TODO: check amount consumed from return value
            // creates new position
            Positions.add(
                zeroForOne ? positions0 : positions1,
                zeroForOne ? ticks0 : ticks1,
                tickNodes,
                state,
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
        (,,lower,upper) = Positions.update(
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
            Positions.remove(
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
    }

    function collect(
        int24 lower,
        int24 upper,
        int24 claim,
        bool  zeroForOne
    ) public lock returns (uint256 amountIn, uint256 amountOut) {
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
        (amountIn,amountOut,,) = Positions.update(
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
        if (state.latestTick < TickMath.MIN_TICK) revert WaitUntilEnoughObservations();
        PoolState memory pool = zeroForOne ? pool1 : pool0;
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
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6)
        });

        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        uint256 nextTickPrice = zeroForOne ? uint256(TickMath.getSqrtRatioAtTick(state.latestTick - int24(tickSpacing)))
                                           : uint256(TickMath.getSqrtRatioAtTick(state.latestTick + int24(tickSpacing)));
        uint256 nextPrice = nextTickPrice;

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price, false);
            // console.log("max dx:", maxDx);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input)
                );
                if (!(nextPrice <= newPrice && newPrice < cache.price)) {
                    newPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                }
                // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                amountOut = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                cache.price= newPrice;
                cache.input = 0;
            } else {
                amountOut = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                cache.price= nextPrice;
                cache.input -= maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextTickPrice, false);
            // console.log("max dy:", maxDy);
            if (cache.input <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.liquidity);
                // Calculate output of swap
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                cache.price = newPrice;
                cache.input = 0;
            } else {
                // Swap & cross the tick.
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                cache.price = nextTickPrice;
                cache.input -= maxDy;
            }
        }

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
    }

    function _validatePosition(int24 lower, int24 upper, bool zeroForOne, uint128 amountDesired) internal view {
        if (lower % int24(tickSpacing) != 0) revert InvalidTick();
        if (upper % int24(tickSpacing) != 0) revert InvalidTick();
        if (amountDesired == 0) revert InvalidPosition();
        if (lower >= upper) revert InvalidPosition();
        if (zeroForOne) {
            if (lower >= state.latestTick) revert InvalidPosition();
        } else {
            if (upper <= state.latestTick) revert InvalidPosition();
        }
    }

    function getAmountIn(
        bool zeroForOne,
        uint256 amountIn,
        uint160 priceLimit
    ) internal view returns (uint256 inAmount, uint256 outAmount) {
        // TODO: make override
        SwapCache memory cache = SwapCache({
            price: zeroForOne ? pool1.price : pool0.price,
            liquidity: zeroForOne ? pool1.liquidity : pool0.liquidity,
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max state.latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6)
        });
        /// @dev - liquidity range is limited to one tick within state.latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to state.latestTick
        uint256 nextTickPrice = zeroForOne ? uint256(TickMath.getSqrtRatioAtTick(state.latestTick - int24(tickSpacing))) :
                                             uint256(TickMath.getSqrtRatioAtTick(state.latestTick + int24(tickSpacing))) ;
        uint256 nextPrice = nextTickPrice;

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price, false);
            // console.log("max dx:", maxDx);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input)
                );
                if (!(nextPrice <= newPrice && newPrice < cache.price)) {
                    newPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                }
                // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                outAmount = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                inAmount  = amountIn;
            } else {
                // Execute swap step and cross the tick.
                outAmount = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                inAmount = maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextTickPrice, false);
            if (cache.input <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.liquidity);
                // Calculate output of swap
                outAmount = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                inAmount = amountIn;
            } else {
                // Swap & cross the tick.
                outAmount = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                inAmount = maxDy;
            }
        }
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
        inAmount -= cache.input;

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
    // function _updatePosition(
    //     address owner,
    //     int24 lower,
    //     int24 upper,
    //     int24 claim,
    //     bool zeroForOne,
    //     int128 amount
    // ) internal returns (uint128, uint128) {
    //     mapping (int24 => Tick) storage ticks = zeroForOne ? ticks0 : ticks1;
    //     UpdatePositionCache memory cache = UpdatePositionCache({
    //         position: zeroForOne ? positions0[owner][lower][upper] : positions1[owner][lower][upper],
    //         feeGrowthCurrentEpoch: zeroForOne ? pool0.feeGrowthCurrentEpoch : pool1.feeGrowthCurrentEpoch,
    //         priceLower: TickMath.getSqrtRatioAtTick(lower),
    //         priceUpper: TickMath.getSqrtRatioAtTick(upper),
    //         claimPrice: TickMath.getSqrtRatioAtTick(claim),
    //         claimTick: tickNodes[claim],
    //         removeLower: true,
    //         removeUpper: true,
    //         amountInDelta: 0,
    //         amountOutDelta: 0
    //     });

    //     /// validate burn amount
    //     if (amount < 0 && uint128(-amount) > cache.position.liquidity) revert NotEnoughPositionLiquidity();

    //     /// validate mint amount 
    //     if (amount > 0 && uint128(amount) + cache.position.liquidity > MAX_TICK_LIQUIDITY) revert MaxTickLiquidity();

    //     /// validate claim param
    //     if (cache.position.claimPriceLast > cache.claimPrice) revert InvalidClaimTick();
    //     if (claim < lower || claim > upper) revert InvalidClaimTick();

    //     /// initialize new position
    //     if (cache.position.claimPriceLast == 0) {
    //         cache.position.accumEpochLast = state.accumEpoch;
    //         cache.position.claimPriceLast = zeroForOne ? uint160(cache.priceUpper) : uint160(cache.priceLower);
    //     }
        
    //     /// handle claims
    //     if (claim == (zeroForOne ? lower : upper)){
    //         /// position filled
    //         if (cache.claimTick.accumEpochLast <= cache.position.accumEpochLast) revert WrongTickClaimedAt();
    //         {
    //             /// @dev - next tick having fee growth means liquidity was cleared
    //             uint32 claimNextTickAccumEpoch = zeroForOne ? tickNodes[cache.claimTick.previousTick].accumEpochLast 
    //                                                         : tickNodes[cache.claimTick.nextTick].accumEpochLast;
    //             if (claimNextTickAccumEpoch > cache.position.accumEpochLast) zeroForOne ? cache.removeLower = false 
    //                                                                                     : cache.removeUpper = false;
    //         }
    //         /// @dev - ignore carryover for last tick of position
    //         cache.amountInDelta  = ticks[claim].amountInDelta - int64(ticks[claim].amountInDeltaCarryPercent) 
    //                                                                 * ticks[claim].amountInDelta / 1e18;
    //         cache.amountOutDelta = ticks[claim].amountOutDelta - int64(ticks[claim].amountOutDeltaCarryPercent)
    //                                                                     * ticks[claim].amountInDelta / 1e18;
    //     } 
    //     else {
    //         if (cache.position.liquidity > 0) {
    //             ///@dev - next accumEpoch should not be greater
    //             uint32 claimNextTickAccumEpoch = zeroForOne ? tickNodes[cache.claimTick.previousTick].accumEpochLast 
    //                                                         : tickNodes[cache.claimTick.nextTick].accumEpochLast;
    //             console.log('claim check');
    //             console.logInt(claim);
    //             console.logInt(cache.claimTick.nextTick);
    //             console.log(claimNextTickAccumEpoch);
    //             console.log(cache.claimTick.accumEpochLast);
    //             console.log(cache.position.accumEpochLast);
    //             if (claimNextTickAccumEpoch > cache.position.accumEpochLast) revert WrongTickClaimedAt();
    //         }
    //         if (amount < 0) {
    //             /// @dev - check if liquidity removal required
    //             cache.removeLower = zeroForOne ? 
    //                                   true
    //                                 : tickNodes[cache.claimTick.nextTick].accumEpochLast      <= cache.position.accumEpochLast;
    //             cache.removeUpper = zeroForOne ? 
    //                                   tickNodes[cache.claimTick.previousTick].accumEpochLast  <= cache.position.accumEpochLast
    //                                 : true;
                
    //         }
    //         if (claim != (zeroForOne ? upper : lower)) {
    //             /// position partial fill
    //             cache.amountInDelta  += ticks[claim].amountInDelta;
    //             cache.amountOutDelta += ticks[claim].amountOutDelta;
    //             /// @dev - no amount deltas for 0% filled
    //             ///TODO: handle partial fill at lower tick
    //         }
    //         if (zeroForOne ? 
    //             (state.latestTick < claim && state.latestTick >= lower) //TODO: not sure if second condition is possible
    //           : (state.latestTick > claim && state.latestTick <= upper) 
    //         ) {
    //             //handle state.latestTick partial fill
    //             uint160 latestTickPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
    //             //TODO: stop accumulating the tick before state.latestTick when moving TWAP
    //             cache.amountInDelta += int128(int256(zeroForOne ? 
    //                     DyDxMath.getDy(
    //                         1, // multiplied by liquidity later
    //                         latestTickPrice,
    //                         pool0.price,
    //                         false
    //                     )
    //                     : DyDxMath.getDx(
    //                         1, 
    //                         pool1.price,
    //                         latestTickPrice, 
    //                         false
    //                     )
    //             ));
    //             //TODO: implement stopPrice for pool0/1
    //             cache.amountOutDelta += int128(int256(zeroForOne ? 
    //                 DyDxMath.getDx(
    //                     1, // multiplied by liquidity later
    //                     pool0.price,
    //                     cache.claimPrice,
    //                     false
    //                 )
    //                 : DyDxMath.getDy(
    //                     1, 
    //                     cache.claimPrice,
    //                     pool1.price, 
    //                     false
    //                 )
    //             ));
    //             //TODO: do we need to handle minus deltas correctly depending on direction
    //             // modify current liquidity
    //             if (amount < 0) {
    //                 zeroForOne ? pool0.liquidity -= uint128(-amount) 
    //                            : pool1.liquidity -= uint128(-amount);
    //             }
    //         }
    //     }
    //     if (claim != (zeroForOne ? upper : lower)) {
    //         //TODO: switch to being the current price if necessary
    //         cache.position.claimPriceLast = cache.claimPrice;
    //         {
    //             // calculate what is claimable
    //             //TODO: should this be inside Ticks library?
    //             uint256 amountInClaimable  = zeroForOne ? 
    //                                             DyDxMath.getDy(
    //                                                 cache.position.liquidity,
    //                                                 cache.claimPrice,
    //                                                 cache.position.claimPriceLast,
    //                                                 false
    //                                             )
    //                                             : DyDxMath.getDx(
    //                                                 cache.position.liquidity, 
    //                                                 cache.position.claimPriceLast,
    //                                                 cache.claimPrice, 
    //                                                 false
    //                                             );
    //             if (cache.amountInDelta > 0) {
    //                 amountInClaimable += FullPrecisionMath.mulDiv(
    //                                                                 uint128(cache.amountInDelta),
    //                                                                 cache.position.liquidity, 
    //                                                                 Ticks.Q128
    //                                                             );
    //             } else if (cache.amountInDelta < 0) {
    //                 //TODO: handle underflow here
    //                 amountInClaimable -= FullPrecisionMath.mulDiv(
    //                                                                 uint128(-cache.amountInDelta),
    //                                                                 cache.position.liquidity, 
    //                                                                 Ticks.Q128
    //                                                             );
    //             }
    //             //TODO: add to position
    //             if (amountInClaimable > 0) {
    //                 amountInClaimable *= (1e6 + swapFee) / 1e6; // factor in swap fees
    //                 cache.position.amountIn += uint128(amountInClaimable);
    //             }
    //         }
    //         {
    //             if (cache.amountOutDelta > 0) {
    //                 cache.position.amountOut += uint128(FullPrecisionMath.mulDiv(
    //                                                                     uint128(cache.amountOutDelta),
    //                                                                     cache.position.liquidity, 
    //                                                                     Ticks.Q128
    //                                                                 )
    //                                                    );
    //             }
    //         }
    //     }

    //     // if burn or second mint
    //     if (amount < 0 || (amount > 0 && cache.position.liquidity > 0 && claim > lower)) {
    //         Ticks.remove(
    //             zeroForOne ? ticks0 : ticks1,
    //             tickNodes,
    //             zeroForOne ? lower : claim,
    //             zeroForOne ? claim : upper,
    //             uint104(uint128(-amount)),
    //             zeroForOne,
    //             cache.removeLower,
    //             cache.removeUpper
    //         );
    //         // they should also get amountOutDeltaCarry
    //         cache.position.amountOut += uint128(zeroForOne ? 
    //             DyDxMath.getDx(
    //                 uint128(-amount),
    //                 cache.priceLower,
    //                 cache.claimPrice,
    //                 false
    //             )
    //             : DyDxMath.getDy(
    //                 uint128(-amount),
    //                 cache.claimPrice,
    //                 cache.priceUpper,
    //                 false
    //             )
    //         );
    //         if (amount < 0) {
    //             // remove position liquidity
    //             cache.position.liquidity -= uint128(-amount);
    //         } else {
    //             // remove old position liquidity
    //             cache.position.liquidity = 0;
    //         }
    //     } 
    //     if (amount > 0) {
    //         ///TODO: do tick insert here
    //         // handle double minting of position
    //         if(cache.position.liquidity > 0) {
    //             zeroForOne ? 
    //             delete positions0[owner][lower][upper]
    //           : delete positions1[owner][lower][upper];
    //         }
    //         cache.position.liquidity += uint128(amount);
    //         console.log('position liquidity:', cache.position.liquidity);
    //         // Prevents a global liquidity overflow in even if all ticks are initialised.
    //         if (cache.position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
    //     }

    //     zeroForOne ? positions0[owner][lower][claim] = cache.position 
    //                : positions1[owner][claim][upper] = cache.position;

    //     return (cache.position.amountIn, cache.position.amountOut);
    // }
}
