// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//TODO: deploy library code once and reference from factory
// have interfaces for library contracts
import "./interfaces/IPoolsharkHedgePool.sol";
import "./interfaces/IPositionManager.sol";
import "./interfaces/IConcentratedPool.sol";
import "./base/PoolsharkHedgePoolStorage.sol";
import "./base/PoolsharkHedgePoolView.sol";
import "./base/PoolsharkHedgePoolEvents.sol";
import "./libraries/Ticks.sol";
import "./libraries/TickMath.sol";
import "./utils/SafeTransfers.sol";
import "./utils/PoolsharkErrors.sol";
import "hardhat/console.sol";

/// @notice Trident Concentrated liquidity pool implementation.
/// @dev SafeTransfers contains PoolsharkHedgePoolErrors
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkHedgePoolView,
    PoolsharkTicksErrors,
    PoolsharkMiscErrors,
    PoolsharkPositionErrors,
    SafeTransfers
{
    uint24 internal immutable tickSpacing;
    uint24 internal immutable swapFee; /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
    uint128 internal immutable MAX_TICK_LIQUIDITY;

    address internal immutable factory;
    address internal immutable inputPool;
    address internal immutable tokenIn;
    address internal immutable tokenOut;

    modifier lock() {
        if (unlocked == 2) revert Locked();
        unlocked = 2;
        _;
        unlocked = 1;
    }

    constructor(bytes memory _poolParams) {
        (
            address _factory,
            address _inputPool,
            address _libraries,
            address _tokenIn, 
            address _tokenOut, 
            uint24  _swapFee, 
            uint24  _tickSpacing,
            bool    _lpZeroForOne
        ) = abi.decode(
            _poolParams,
            (
                address, 
                address,
                address,
                address,
                address,
                uint24,
                uint24,
                bool
            )
        );
        if(_lpZeroForOne) revert NotImplementedYet();

        // check for invalid params
        if (_tokenIn == address(0) || _tokenIn == address(this)) revert InvalidToken();
        if (_tokenOut == address(0) || _tokenOut == address(this)) revert InvalidToken();
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = _factory;
        inputPool   = _inputPool;
        utils       = IPoolsharkUtils(_libraries);
        tokenIn     = _lpZeroForOne ? _tokenOut : _tokenIn;
        tokenOut    = _lpZeroForOne ? _tokenIn : _tokenOut;
        swapFee     = _swapFee;
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(_factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);

        // set default initial values
        //TODO: insertSingle or pass MAX_TICK as upper
        // @dev increase pool observations if not sufficient
        latestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        if (latestTick >= TickMath.MIN_TICK) { _initialize(); }
    }

    //TODO: test this check
    function _ensureInitialized() internal {
        if (latestTick < TickMath.MIN_TICK) {
            if(utils.isPoolObservationsEnough(IConcentratedPool(inputPool))) {
                _initialize();
            }
            revert WaitUntilEnoughObservations(); 
        }
    }

    function _initialize() internal {
        latestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        if (latestTick != TickMath.MIN_TICK && latestTick != TickMath.MAX_TICK) {
            ticks[latestTick] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
            ticks[TickMath.MIN_TICK] = Tick(
                TickMath.MIN_TICK, latestTick,
                0,0,0,0,0
            );
            ticks[TickMath.MAX_TICK] = Tick(
                latestTick, TickMath.MAX_TICK,
                0,0,0,0,0
            );
        } else if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) {
            ticks[TickMath.MIN_TICK] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
            ticks[TickMath.MAX_TICK] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK,
                0,0,0,0,0
            );
        }
        nearestTick = latestTick;
        sqrtPrice = TickMath.getSqrtRatioAtTick(nearestTick);
        unlocked = 1;
        lastBlockNumber = uint32(block.number);
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        _ensureTickSpacing(mintParams.lower, mintParams.upper);
        _ensureInitialized();

        if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
        if (mintParams.lower >= mintParams.upper) { revert InvalidPosition(); }

        if(block.number != lastBlockNumber) {
            _accumulateLastBlock();
        }

        if (mintParams.lower <= latestTick) { revert InvalidPosition(); }

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));

        liquidityMinted = utils.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            priceUpper,
            uint256(mintParams.amountDesired),
            0
        );

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert Overflow();

        if (!mintParams.zeroForOne && mintParams.lower < latestTick ) {
            // handle partial mints
            mintParams.lower = latestTick;
            mintParams.lowerOld = ticks[latestTick].previousTick;
            uint256 priceLatestTick = TickMath.getSqrtRatioAtTick(mintParams.lower);
            mintParams.amountDesired -= uint128(utils.getDy(liquidityMinted, priceLower, priceLatestTick, false));
        }

        if(!mintParams.zeroForOne){
            _transferIn(tokenOut, mintParams.amountDesired);
        } else {
            revert NotImplementedYet();
        }

        unchecked {
            _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                mintParams.lower,
                int128(uint128(liquidityMinted))
            );
            // only increase liquidity if nearestTick and lower are equal to latestTick
            // this should be the only case where that is true
            if (mintParams.lower == nearestTick) liquidity += uint128(liquidityMinted);
        }

        nearestTick = Ticks.insert(
            ticks,
            feeGrowthGlobalIn,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            nearestTick,
            latestTick,
            uint160(sqrtPrice)
        );

        (uint128 amountInActual, uint128 amountOutActual) = utils.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            priceUpper,
            liquidityMinted,
            true
        );

        emit Mint(msg.sender, amountInActual, amountOutActual);
    }

    function burn(
        int24 lower,
        int24 upper,
        int24 claim,
        uint128 amount
    )
        public
        lock
        returns (
            uint256 tokenInAmount,
            uint256 tokenOutAmount
        )
    {
        uint160 priceLower = TickMath.getSqrtRatioAtTick(lower);
        uint160 priceUpper = TickMath.getSqrtRatioAtTick(upper);
        uint160 currentPrice= sqrtPrice;

        // console.log('zero previous tick:');
        // console.logInt(ticks[0].previousTick);

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
        }
        // console.log('zero previous tick:');
        // console.logInt(ticks[0].previousTick);

        // only remove liquidity if lower if below currentPrice
        unchecked {
            if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity -= amount;
        }

        // handle liquidity withdraw and transfer out in _updatePosition

        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert Overflow();

        // _updatePosition(msg.sender, lower, upper, -int128(amount));
        _updatePosition(
            msg.sender,
            lower,
            upper,
            claim,
            -int128(amount)
        );

        uint256 amountIn;
        uint256 amountOut;
        console.logInt(ticks[latestTick].nextTick);
        nearestTick = Ticks.remove(ticks, lower, upper, amount, nearestTick);

        // get token amounts from _updatePosition return values
        emit Burn(msg.sender, amountIn, amountOut);
    }

    // function collect(int24 lower, int24 upper) public lock returns (uint256 amountInfees, uint256 amountOutfees) {
    //     (amountInfees, amountOutfees) = _updatePosition(
    //                                      msg.sender, 
    //                                      lower, 
    //                                      upper, 
    //                                      0
    //                                  );
    //     // address owner,
    //     // int24 lower,
    //     // int24 upper,
    //     // bool zeroForOne,
    //     // int128 amount,
    //     // bool claiming,
    //     // int24 claim

    //     _transferBothTokens(msg.sender, amountInfees, amountOutfees);

    //     emit Collect(msg.sender, amountInfees, amountOutfees);
    // }

    /// @dev Swaps one token for another. The router must prefund this contract and ensure there isn't too much slippage.
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
        // bytes calldata data
    ) external override lock returns (uint256 amountOut) {
        if (!zeroForOne) revert NotImplementedYet();

        TickMath.validatePrice(sqrtPriceLimitX96);

        _transferIn(tokenIn, amountIn);

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
        }

        feeGrowthGlobalIn += utils.mulDivRoundingUp(amountIn, swapFee, 1e6);

        SwapCache memory cache = SwapCache({
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            currentTick: nearestTick,
            currentPrice: uint256(sqrtPrice),
            currentLiquidity: uint256(liquidity),
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            nextTickToCross: ticks[nearestTick].previousTick
        });

        console.log('starting tick:');
        console.logInt(cache.currentTick);
        console.log("liquidity:", cache.currentLiquidity);
        console.logInt(cache.nextTickToCross);

        uint256 output = 0;

        uint256 nextTickSqrtPrice = uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
        uint256 nextSqrtPrice = nextTickSqrtPrice;
        // console.log("next price:", nextSqrtPrice);
        
        bool cross = false;

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // sqrtPrice  is decreasing.
            // Maximum input amount within current tick range: Δx = Δ(1/√𝑃) · L.
            if (nextSqrtPrice < sqrtPriceLimitX96) { nextSqrtPrice = sqrtPriceLimitX96; }
            uint256 maxDx = utils.getDx(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);
            console.log("max dx:", maxDx);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.currentLiquidity << 96;
                // calculate price after swap
                uint256 newSqrtPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, cache.currentPrice, liquidityPadded + cache.currentPrice * cache.input)
                );

                if (!(nextSqrtPrice <= newSqrtPrice && newSqrtPrice < cache.currentPrice)) {
                    // Overflow. We use a modified version of the formula.
                    newSqrtPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / cache.currentPrice+ cache.input));
                }
                // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                amountOut = utils.getDy(cache.currentLiquidity, newSqrtPrice, cache.currentPrice, false);
                // console.log("dtokenOut:", output);
                cache.currentPrice= newSqrtPrice;
                cache.input = 0;
            } else {
                // Execute swap step and cross the tick.
                // console.log('nextsqrtprice:', nextSqrtPrice);
                // console.log('currentprice:', cache.currentPrice);
                amountOut = utils.getDy(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);
                // console.log("dtokenOut:", output);
                cache.currentPrice= nextSqrtPrice;
                if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                cache.input -= maxDx;
            }
        } else {
            revert NotImplementedYet();
        }

        // console.log("liquidity:", cache.currentLiquidity);
        // It increases each swap step.
        // amountOut += output;

        sqrtPrice = uint160(cache.currentPrice);

        // console.log('fee growth:', cache.feeGrowthGlobal);
        // console.log('output:');
        // console.log(amountOut);
        // console.log('new price:', sqrtPrice);
        // console.log('current tick:');
        // console.log(cache.currentLiquidity);
        // console.logInt( cache.currentTick);
        // console.log('new nearest tick:');
        // console.logInt(nearestTick);

        if (zeroForOne) {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                feeGrowthGlobalIn -= feeReturn;
                _transferOut(recipient, tokenIn, cache.input + feeReturn);
            }
            _transferOut(recipient, tokenOut, amountOut);
            emit Swap(recipient, tokenIn, tokenOut, amountIn, amountOut);
        } else {
            // if(cache.input > 0) {
            //     uint128 feeReturn = uint128(
            //                             cache.input * 1e18 
            //                             / (amountIn - cache.feeAmount) 
            //                             * cache.feeAmount / 1e18
            //                            );
            //     feeGrowthGlobalOut -= feeReturn;
            //     _transferOut(recipient, tokenOut, cache.input + feeReturn);
            // }
            // _transferOut(recipient, tokenIn, amountOut);
            // emit Swap(recipient, tokenOut, tokenIn, amountIn, amountOut);
            revert NotImplementedYet();
        }
    }

    function _ensureTickSpacing(int24 lower, int24 upper) internal view {
        if (lower % int24(tickSpacing) != 0) revert InvalidTick();
        if (upper % int24(tickSpacing) != 0) revert InvalidTick();
    }

    function getAmountIn(bytes calldata data) internal view returns (uint256 finalAmountIn) {
        // TODO: make override
        (address outToken, uint256 amountOut) = abi.decode(data, (address, uint256));
        uint256 amountOutWithoutFee = (amountOut * 1e6) / (1e6 - swapFee) + 1;
        uint256 currentPrice = uint256(sqrtPrice);
        int24 nextTickToCross = tokenOut == tokenOut ? nearestTick : ticks[nearestTick].nextTick;
        int24 nextTick;

        finalAmountIn = 0;
        uint256 nextTickPrice = uint256(TickMath.getSqrtRatioAtTick(nextTickToCross));
        if (outToken == tokenOut) {
            uint256 currentLiquidity = uint256(liquidity);
            uint256 maxDy = utils.getDy(currentLiquidity, nextTickPrice, currentPrice, false);
            if (amountOutWithoutFee <= maxDy) {
                unchecked {
                    amountOut = (amountOut * 1e6) / (1e6 - swapFee) + 1;
                }
                uint256 newPrice = currentPrice - utils.mulDiv(amountOut, 0x1000000000000000000000000, currentLiquidity);
                finalAmountIn += (utils.getDx(currentLiquidity, newPrice, currentPrice, false) + 1);
            } else {
                finalAmountIn += utils.getDx(currentLiquidity, nextTickPrice, currentPrice, false);
                unchecked {
                    int128 liquidityDelta = ticks[nextTickToCross].liquidityDelta;
                    if (liquidityDelta < 0) {
                        currentLiquidity -= uint128(-liquidityDelta);
                    } else {
                        currentLiquidity += uint128(liquidityDelta);
                    }
                    amountOutWithoutFee -= maxDy;
                    amountOutWithoutFee += 1; // to compensate rounding issues
                    uint256 feeAmount = utils.mulDivRoundingUp(maxDy, swapFee, 1e6);
                    amountOut -= (maxDy - feeAmount);
                }
                nextTick = ticks[nextTickToCross].previousTick;
            }
        } else {
            uint256 currentLiquidity = uint256(liquidity);
            uint256 maxDx = utils.getDx(currentLiquidity, currentPrice, nextTickPrice, false);

            if (amountOutWithoutFee <= maxDx) {
                unchecked {
                    amountOut = (amountOut * 1e6) / (1e6 - swapFee) + 1;
                }
                uint256 liquidityPadded = currentLiquidity << 96;
                uint256 newPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, currentPrice, liquidityPadded - currentPrice * amountOut)
                );
                if (!(currentPrice < newPrice && newPrice <= nextTickPrice)) {
                    // Overflow. We use a modified version of the formula.
                    newPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / currentPrice - amountOut));
                }
                finalAmountIn += (utils.getDy(currentLiquidity, currentPrice, newPrice, false) + 1);
            } else {
                // Swap & cross the tick.
                finalAmountIn += utils.getDy(currentLiquidity, currentPrice, nextTickPrice, false);
                unchecked {
                    int128 liquidityDelta = ticks[nextTickToCross].liquidityDelta;
                    if (liquidityDelta < 0) {
                        currentLiquidity -= uint128(-liquidityDelta);
                    } else {
                        currentLiquidity += uint128(liquidityDelta);
                    }
                    amountOutWithoutFee -= maxDx;
                    amountOutWithoutFee += 1; // to compensate rounding issues
                    uint256 feeAmount = utils.mulDivRoundingUp(maxDx, swapFee, 1e6);
                    amountOut -= (maxDx - feeAmount);
                }
                nextTick = ticks[nextTickToCross].nextTick;
            }
        }
        currentPrice = nextTickPrice;
        if (nextTickToCross == nextTick) {
            revert NotEnoughOutputLiquidity();
        }
        nextTickToCross = nextTick;
    }


    function _transferBothTokens(
        address to,
        uint256 shares0,
        uint256 shares1
    ) internal {
        _transferOut(to, tokenIn, shares0);
        _transferOut(to, tokenOut, shares1);
    }

    //TODO: zap into LP position
    //TODO: use bitmaps to naiively search for the tick closest to the new TWAP
    //TODO: assume everything will get filled for now
    //TODO: remove old latest tick if necessary
    //TODO: after accumulation, all liquidity below old latest tick is removed
    function _accumulateLastBlock() internal {
        console.log("-- START ACCUMULATE LAST BLOCK --");
        // get the next price update
        int24   nextLatestTick = utils.calculateAverageTick(IConcentratedPool(inputPool));

        // only accumulate if...
        if (nextLatestTick == latestTick                         // latestTick has moved OR
            && liquidity != 0) {  // latestTick is not filled
            return;
        }

        console.log('zero tick previous:');
        console.logInt(ticks[0].previousTick);

        AccumulateCache memory cache = AccumulateCache({
            currentTick: nearestTick,
            currentPrice: sqrtPrice,
            currentLiquidity: uint256(liquidity),
            nextTickToCross: ticks[nearestTick].nextTick,
            feeGrowthGlobal: feeGrowthGlobalIn
        });

        bool isPartialTickFill = liquidity > 0 && cache.currentPrice != TickMath.getSqrtRatioAtTick(cache.currentTick);
        // first tick has unfilled amount since price doesn't match tick
        if(isPartialTickFill) {
            console.log('rolling over');
            Ticks.rollover(
                ticks,
                cache.currentTick,
                cache.nextTickToCross,
                sqrtPrice,
                uint256(liquidity)
            );
            Ticks.accumulate(
                ticks,
                cache.currentTick,
                cache.nextTickToCross,
                cache.currentLiquidity,
                feeGrowthGlobalIn,
                tickSpacing
            );
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
        }

        lastBlockNumber = block.number;

        // if tick is moving up more than one we need to handle deltas
        if (nextLatestTick == latestTick) {
            return;
        } else if (nextLatestTick > latestTick) {
            // cross latestTick if partial fill
            if(isPartialTickFill){
                (
                    cache.currentLiquidity, 
                    cache.currentTick,
                    cache.nextTickToCross
                ) = Ticks.cross(
                    ticks,
                    cache.currentTick,
                    cache.nextTickToCross,
                    cache.currentLiquidity,
                    false
                );
            }

            // iterate to new latest tick
            while (cache.nextTickToCross < nextLatestTick) {
                // only iterate to the new TWAP and update liquidity
                if(cache.currentLiquidity > 0){
                    Ticks.rollover(
                        ticks,
                        cache.currentTick,
                        cache.nextTickToCross,
                        cache.currentPrice,
                        uint256(cache.currentLiquidity)
                    );
                }
                Ticks.accumulate(
                    ticks,
                    cache.currentTick,
                    cache.nextTickToCross,
                    cache.currentLiquidity,
                    feeGrowthGlobalIn,
                    tickSpacing
                );
                (
                    cache.currentLiquidity,
                    cache.currentTick,
                    cache.nextTickToCross
                ) = Ticks.cross(
                    ticks,
                    cache.currentTick,
                    cache.nextTickToCross,
                    cache.currentLiquidity,
                    false
                );
            }
            // if this is true we need to insert new latestTick
            if (cache.nextTickToCross != nextLatestTick) {
                // if this is true we need to delete the old tick
                if (ticks[latestTick].liquidityDelta == 0 && ticks[latestTick].liquidityDeltaMinus == 0 && cache.currentTick == latestTick) {
                    ticks[nextLatestTick] = Tick(
                        ticks[cache.currentTick].previousTick, 
                        cache.nextTickToCross,
                        0,0,0,0,0
                    );
                    ticks[ticks[cache.currentTick].previousTick].nextTick  = nextLatestTick;
                    ticks[cache.nextTickToCross].previousTick              = nextLatestTick;
                    delete ticks[latestTick];
                } else {
                    ticks[nextLatestTick] = Tick(
                        cache.currentTick, 
                        cache.nextTickToCross,
                        0,0,0,0,0
                    );
                    ticks[cache.currentTick].nextTick = nextLatestTick;
                    ticks[cache.nextTickToCross].previousTick = nextLatestTick;
                }
            }
            nearestTick = nextLatestTick;
        // handle TWAP moving down
        } else if (nextLatestTick < latestTick) {
            // save current liquidity and set liquidity to zero
            ticks[latestTick].liquidityDelta += int128(liquidity);
            liquidity = 0;
            cache.nextTickToCross = ticks[nearestTick].previousTick;
            while (cache.nextTickToCross > nextLatestTick) {
                (
                    , 
                    cache.currentTick,
                    cache.nextTickToCross
                ) = Ticks.cross(
                    ticks,
                    cache.currentTick,
                    cache.nextTickToCross,
                    0,
                    true
                );
            }
            console.log('cross to next latest tick:');
            console.logInt(cache.currentTick);
            console.logInt(cache.nextTickToCross);
            // if tick doesn't exist currently
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if (ticks[nextLatestTick].previousTick == 0 && ticks[nextLatestTick].nextTick == 0){
                //TODO: can we assume this is always MIN_TICK?
                ticks[nextLatestTick] = Tick(
                        cache.nextTickToCross, 
                        cache.currentTick,
                        0,0,0,0,0
                );
                ticks[cache.currentTick].nextTick = nextLatestTick;
                ticks[cache.nextTickToCross].previousTick = nextLatestTick;
            }
        }

        console.log('cross last tick touched');
        console.logInt(cache.currentTick);
        console.logInt(ticks[cache.currentTick].nextTick);

        latestTick = nextLatestTick;
        sqrtPrice = TickMath.getSqrtRatioAtTick(nextLatestTick);

        console.log('max tick previous:');
        console.logInt(ticks[887272].previousTick);
        console.logInt(ticks[887272].nextTick);
        //TODO: update liquidity
        // if latestTick didn't change we don't update liquidity
        // if it did we set to current liquidity


        // insert new latest tick
        // console.log('updated tick after insert');
        // console.logInt(ticks[cache.nextTickToCross].previousTick);
        // console.logInt(latestTick);
        // console.logInt(ticks[latestTick].nextTick);
        // console.log('fee growth check:');
        // console.log(ticks[0].feeGrowthGlobalLast);
        // console.log(ticks[20].feeGrowthGlobalLast);
        // console.log(ticks[30].feeGrowthGlobalLast);
        // console.log(ticks[50].feeGrowthGlobalLast);
        console.log("-- END ACCUMULATE LAST BLOCK --");
    }

    //TODO: handle zeroForOne
    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        int24 claim,
        int128 amount
    ) internal {
        // load position into memory
        Position memory position = positions[owner][lower][upper];
        // validate removal amount is less than position liquidity
        if (amount < 0 && uint128(-amount) > position.liquidity) revert NotEnoughPositionLiquidity();

        uint256 priceLower   = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper   = uint256(TickMath.getSqrtRatioAtTick(upper));
        uint256 claimPrice   = uint256(TickMath.getSqrtRatioAtTick(claim));

        if (position.claimPriceLast == 0) {
            position.feeGrowthGlobalLast = feeGrowthGlobalIn;
            position.claimPriceLast = uint160(priceLower);
        }
        if (position.claimPriceLast > claimPrice) revert InvalidClaimTick();

        // handle claims
        if(ticks[claim].feeGrowthGlobalIn > position.feeGrowthGlobalLast) {
            // skip claim if lower == claim
            if(claim != lower){
                // verify user passed highest tick with growth
                if (claim != upper){
                    {
                        // next tick should not have any fee growth
                        int24 claimNextTick = ticks[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobalIn > position.feeGrowthGlobalLast) revert WrongTickClaimedAt();
                    }
                }
                position.claimPriceLast = uint160(claimPrice);
                position.feeGrowthGlobalLast = feeGrowthGlobalIn;
                {
                    // calculate what is claimable
                    uint256 amountInClaimable  = utils.getDx(
                                                        position.liquidity, 
                                                        position.claimPriceLast,
                                                        claimPrice, 
                                                        false
                                                    );// * (1e6 + swapFee) / 1e6; //factors in fees
                    int128 amountInDelta = ticks[claim].amountInDeltaX96;
                    if (amountInDelta > 0) {
                        amountInClaimable += FullPrecisionMath.mulDiv(
                                                                        uint128(amountInDelta),
                                                                        position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    } else if (amountInDelta < 0) {
                        //TODO: handle underflow here
                        amountInClaimable -= FullPrecisionMath.mulDiv(
                                                                        uint128(-amountInDelta),
                                                                        position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    }
                    //TODO: add to position
                    if (amountInClaimable > 0) {
                        _transferOut(owner, tokenIn, amountInClaimable);
                    }
                }
                {
                    int128 amountOutDelta = ticks[claim].amountOutDeltaX96;
                    uint256 amountOutClaimable;
                    if (amountOutDelta > 0) {
                        amountOutClaimable = FullPrecisionMath.mulDiv(
                                                                        uint128(amountOutDelta),
                                                                        position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                        _transferOut(owner, tokenIn, amountOutClaimable);
                    }
                    //TODO: add to position
                    
                }
            }
        }   

        // liquidity updated in burn() function
        if (amount < 0) {
            // calculate amount to transfer out
            // TODO: ensure no liquidity above has been touched
            uint256 amountOutRemoved = utils.getDy(
                uint128(-amount),
                claimPrice,
                priceUpper,
                false
            );
            console.log('amount out removed:', amountOutRemoved);
            // will underflow if too much liquidity withdrawn
            uint128 liquidityAmount = uint128(-amount);
            position.liquidity -= liquidityAmount;
            _transferOut(owner, tokenOut, amountOutRemoved);
        }

        if (amount > 0) {
            //TODO: i'm not sure how to handle double mints just yet
            // one solution is to take all their current liquidity
            // and then respread it over whatever range they select
            // if they haven't claimed at all it's fine
            // second solution is to recalculate claimPriceLast
            // easiest option is to just reset the position
            // and store the leftover amounts in the position
            // or transfer the leftover balance to the owner
            //TODO: handle double minting of position
            if(position.liquidity > 0) revert NotImplementedYet();
            position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }

        positions[owner][lower][upper] = position;
    }
}
