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

/// @notice Poolshark Directional Liquidity pool implementation.
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
    address internal immutable token0;
    address internal immutable token1;

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
            uint24  _swapFee, 
            uint24  _tickSpacing
        ) = abi.decode(
            _poolParams,
            (
                address, 
                address,
                address,
                uint24,
                uint24
            )
        );

        // check for invalid params
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = _factory;
        inputPool   = _inputPool;
        utils       = IPoolsharkUtils(_libraries);
        token0      = IConcentratedPool(inputPool).token0();
        token1      = IConcentratedPool(inputPool).token1();
        swapFee     = _swapFee;
        //TODO: should be 1% for .1% spacing on inputPool
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(_factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);

        // set default initial values
        //TODO: insertSingle or pass MAX_TICK as upper
        // @dev increase pool observations if not sufficient
        latestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        if (latestTick >= TickMath.MIN_TICK) {
            _initialize(true); 
            _initialize(false);
            unlocked = 1;
            lastBlockNumber = uint32(block.number);
        }
    }

    //TODO: test this check
    function _ensureInitialized() internal {
        if (latestTick < TickMath.MIN_TICK) {
            if(utils.isPoolObservationsEnough(IConcentratedPool(inputPool))) {
                _initialize(true);
                _initialize(false);
                unlocked = 1;
                lastBlockNumber = uint32(block.number);

            }
            revert WaitUntilEnoughObservations(); 
        }
    }

    function _initialize(bool isPool0) internal {
        int24 initLatestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        latestTick = initLatestTick / tickSpacing * tickSpacing;
        mapping(int24 => Tick) ticks = isPool0 ? ticks0 : ticks1;
        PoolState memory pool = isPool0 ? pool0 : pool1;
        if (latestTick != TickMath.MIN_TICK && latestTick != TickMath.MAX_TICK) {
            ticks[latestTick] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
            ticks[TickMath.MIN_TICK] = Tick(
                TickMath.MIN_TICK, latestTick
            );
            ticks[TickMath.MAX_TICK] = Tick(
                latestTick, TickMath.MAX_TICK
            );
        } else if (latestTick == TickMath.MIN_TICK || latestTick == TickMath.MAX_TICK) {
            ticks[TickMath.MIN_TICK] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
            ticks[TickMath.MAX_TICK] = Tick(
                TickMath.MIN_TICK, TickMath.MAX_TICK
            );
        }

        //TODO: we might not need nearestTick; always with defined tickSpacing
        pool.nearestTick = isPool0 ? initLatestTick : TickMath.MIN_TICK;
        //TODO: the sqrtPrice cannot move more than 1 tickSpacing away
        pool.price = TickMath.getSqrtRatioAtTick(initLatestTick);
        isPool0 ? pool0 = pool : pool1 = pool;
        //TODO: do we keep this?

    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        /// @dev - don't allow mints until we have enough observations from inputPool
        _ensureInitialized();

        if(block.number != lastBlockNumber) {
            _accumulateLastBlock(mintParams.zeroForOne);
        }
        //TODO: handle upperOld and lowerOld being invalid
        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        //TODO: maybe move to other function
        // handle partial mints
        if (mintParams.zeroForOne && mintParams.upper >= latestTick) {
            mintParams.upper = latestTick - tickSpacing;
            mintParams.upperOld = latestTick;
            uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(mintParams.upper);
            mintParams.amountDesired -= uint128(utils.getDx(liquidityMinted, priceNewUpper, priceUpper, false));
            priceUpper = priceNewUpper;
        }
        if (!mintParams.zeroForOne && mintParams.lower <= latestTick) {
            mintParams.lower = latestTick + tickSpacing;
            mintParams.lowerOld = latestTick;
            uint256 priceNewLower = TickMath.getSqrtRatioAtTick(mintParams.lower);
            mintParams.amountDesired -= uint128(utils.getDy(liquidityMinted, priceLower, priceNewLower, false));
            priceLower = priceNewLower;
        }

        _validatePosition(mintParams);

        liquidityMinted = utils.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            MintParams.zeroForOne ? priceLower : priceUpper,
            MintParams.zeroForOne ? 0 : uint256(mintParams.amountDesired),
            MintParams.zeroForOne ? uint256(mintParams.amountDesired) : 0
        );

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();

        if(mintParams.zeroForOne){
            _transferIn(token0, mintParams.amountDesired);
        } else {
            _transferIn(token1, mintParams.amountDesired);
        }

        unchecked {
            _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                mintParams.zeroForOne ? mintParams.upper : mintParams.lower,
                mintParams.zeroForOne,
                int128(uint128(liquidityMinted))
            );
            /// @dev - pool current liquidity should never be increased on mint
        }

        Ticks.insert(
            mintParams.zeroForOne ? ticks0 : ticks1,
            mintParams.zeroForOne ? feeGrowthGlobalIn1 : feeGrowthGlobalIn0,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            mintParams.zeroForOne ? pool0.nearestTick : pool1.nearestTick,
            latestTick,
            mintParams.zeroForOne ? uint160(pool0.price) : uint160(pool1.price)
        );

        (uint128 amountInActual, uint128 amountOutActual) = utils.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            MintParams.zeroForOne ? priceLower : priceUpper,
            liquidityMinted,
            true
        );

        emit Mint(msg.sender, amountInActual, amountOutActual);
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
        /// @dev - not necessary since position will be empty
        // _ensureInitialized();
        uint160 priceLower = TickMath.getSqrtRatioAtTick(lower);
        uint160 priceUpper = TickMath.getSqrtRatioAtTick(upper);
        uint160 currentPrice = zeroForOne ? pool0.price : pool1.price;

        // console.log('zero previous tick:');
        // console.logInt(ticks[0].previousTick);

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock(zeroForOne);
        }
        // console.log('zero previous tick:');
        // console.logInt(ticks[0].previousTick);

        // only remove liquidity if lower if below currentPrice
        //TODO: burning liquidity should take liquidity out past the current auction
        unchecked {
            uint128 liquidity = zeroForOne ? pool0.liquidity : pool1.liquidity;
        }
        
        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();

        // _updatePosition(msg.sender, lower, upper, -int128(amount));
        _updatePosition(
            msg.sender,
            lower,
            upper,
            claim,
            zeroForOne,
            -int128(amount)
        );

        uint256 amountIn;
        uint256 amountOut;
        console.logInt(zeroForOne ? ticks1[latestTick].nextTick : ticks1[latestTick].nextTick);
        Ticks.remove(zeroForOne ? ticks0 : ticks1, lower, upper, amount, latestTick);

        //TODO: get token amounts from _updatePosition return values
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
        uint160 priceLimit
        // bytes calldata data
    ) external override lock returns (uint256 amountOut) {
        //TODO: is this needed?
        if (latestTick < TickMath.MIN_TICK) revert WaitUntilEnoughObservations();

        TickMath.validatePrice(priceLimit);

        _transferIn(zeroForOne ? token0 : token1, amountIn);

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
        }

        SwapCache memory cache = SwapCache({
            price: zeroForOne ? pool1.price : pool0.price,
            liquidity: zeroForOne ? pool1.liquidity : pool0.liquidity,
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6)
        });

        console.log('starting tick:');
        console.logInt(latestTick);
        console.log("liquidity:", cache.liquidity);

        uint256 output;
        /// @dev - liquidity range is limited to one tick within latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to latestTick
        uint256 nextTickPrice = zeroForOne ? uint256(TickMath.getSqrtRatioAtTick(latestTick - tickSpacing)) :
                                             uint256(TickMath.getSqrtRatioAtTick(latestTick + tickSpacing)) ;
        uint256 nextPrice = nextTickPrice;
        // console.log("next price:", nextPrice);

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = utils.getDx(cache.liquidity, nextPrice, cache.price, false);
            console.log("max dx:", maxDx);
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
                amountOut = utils.getDy(cache.liquidity, newPrice, cache.price, false);
                // console.log("dtokenOut:", output);
                cache.price= newPrice;
                cache.input = 0;
            } else {
                // Execute swap step and cross the tick.
                // console.log('nextsqrtprice:', nextPrice);
                // console.log('currentprice:', cache.price);
                amountOut = utils.getDy(cache.liquidity, nextPrice, cache.price, false);
                // console.log("dtokenOut:", output);
                cache.price= nextPrice;
                cache.input -= maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = utils.getDy(cache.liquidity, cache.price, nextTickPrice, false);
            console.log("max dy:", maxDy);
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

        // console.log("liquidity:", cache.liquidity);
        // It increases each swap step.
        // amountOut += output;

        zeroForOne ? pool1.price = uint160(cache.price) : 
                     pool0.price = uint160(cache.price) ;

        // console.log('fee growth:', cache.feeGrowthGlobal);
        // console.log('output:');
        // console.log(amountOut);
        // console.log('new price:', sqrtPrice);
        // console.log('current tick:');
        // console.log(cache.liquidity);
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
                cache.feeAmount -= feeReturn;
                feeGrowthGlobalIn0 += cache.feeAmount; 
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
                feeGrowthGlobalIn1 += cache.feeAmount; 
                _transferOut(recipient, token1, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token1, token0, amountIn, amountOut);
        }
    }

    function _validatePosition(MintParams mintParams) internal view {
        if (mintParams.lower % int24(tickSpacing) != 0) revert InvalidTick();
        if (mintParams.upper % int24(tickSpacing) != 0) revert InvalidTick();
        if (mintParams.amountDesired == 0) revert InvalidPosition();
        if (mintParams.lower >= mintParams.upper) revert InvalidPosition();
        if (mintParams.zeroForOne) {
            if (mintParams.lower >= latestTick) revert InvalidPosition();
        } else {
            if (mintParams.lower <= latestTick) revert InvalidPosition();
        }
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
        _transferOut(to, token0, shares0);
        _transferOut(to, token1, shares1);
    }

    //TODO: zap into LP position
    //TODO: use bitmaps to naiively search for the tick closest to the new TWAP
    //TODO: assume everything will get filled for now
    //TODO: remove old latest tick if necessary
    //TODO: after accumulation, all liquidity below old latest tick is removed
    //TODO: don't update latestTick until TWAP has moved +/- tickSpacing
    //TODO: latestTick needs to be a multiple of tickSpacing
    function _accumulateLastBlock(bool isPool0) internal {
        console.log("-- START ACCUMULATE LAST BLOCK --");
        lastBlockNumber = block.number;
        // get the next price update
        int24   nextLatestTick = utils.calculateAverageTick(IConcentratedPool(inputPool));
        // check for early return
        bool tickFilled = isPool0 ? pool0.price == utils.getSqrtRatioAtTick(pool0.nearestTick)
                                  : pool1.price == utils.getSqrtRatioAtTick(pool1.nearestTick);
        // only accumulate if...
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing) && !tickFilled) {  // latestTick is not filled
            return;
        }

        console.log('zero tick previous:');
        console.logInt(ticks[0].previousTick);

        AccumulateCache memory cache = AccumulateCache({
            tick:      isPool0 ? pool0.nearestTick : pool1.nearestTick,
            price:     isPool0 ? pool0.price : pool1.price,
            liquidity: isPool0 ? uint256(pool0.liquidity) : uint256(pool1.liquidity),
            nextTickToCross:  0,
            nextTickToAccum:  0,
            feeGrowthGlobalIn: isPool0 ? feeGrowthGlobalIn1 : feeGrowthGlobalIn0
        });

        cache.nextTickToCross = isPool0 ? ticks[cache.tick].nextTick 
                                        : cache.tick;
        ///TODO: ensure price != priceAtTick(cache.nextTickToAccum)
        cache.nextTickToAccum = isPool0 ? ticks[cache.tick].previousTick 
                                        : ticks[cache.tick].nextTick;
        // handle partial tick fill
        if(!tickFilled) {
            console.log('rolling over');
            Ticks.rollover(
                isPool0 ? tickData0 : tickData1,
                cache.nextTickToCross,
                cache.nextTickToAccum,
                cache.price,
                cache.liquidity,
                isPool0
            );
            Ticks.accumulate(
                isPool0 ? tickData0 : tickData1,
                cache.tick,
                cache.nextTickToAccum,
                cache.liquidity,
                cache.feeGrowthGlobalIn,
                tickSpacing
            );
            // update liquidity and ticks
            //TODO: do we return here is latestTick has not moved??
        }

        // if tick is moving up more than one we need to handle deltas
        if ((nextLatestTick / tickSpacing) == (latestTick / tickSpacing)) {
            return;
        } else if (nextLatestTick > latestTick) {
            // cross latestTick if partial fill
            if(!tickFilled){
                (
                    cache.liquidity, 
                    cache.tick,
                    cache.nextTick
                ) = Ticks.cross(
                    ticks,
                    cache.tick,
                    cache.nextTick,
                    cache.liquidity,
                    isPool0
                );
            }

            // iterate to new latest tick
            while (cache.nextTick < nextLatestTick) {
                // only iterate to the new TWAP and update liquidity
                if(cache.liquidity > 0){
                    Ticks.rollover(
                        ticks,
                        cache.tick,
                        cache.nextTick,
                        cache.price,
                        uint256(cache.liquidity)
                    );
                }
                Ticks.accumulate(
                    ticks,
                    cache.tick,
                    cache.nextTick,
                    cache.liquidity,
                    cache.feeGrowthGlobalIn,
                    tickSpacing
                );
                (
                    cache.liquidity,
                    cache.tick,
                    cache.nextTick
                ) = Ticks.cross(
                    ticks,
                    cache.tick,
                    cache.nextTick,
                    cache.liquidity,
                    false
                );
            }
            // if this is true we need to insert new latestTick
            if (cache.nextTick != nextLatestTick) {
                // if this is true we need to delete the old tick
                if (ticks[latestTick].liquidityDelta == 0 && ticks[latestTick].liquidityDeltaMinus == 0 && cache.tick == latestTick) {
                    ticks[nextLatestTick] = Tick(
                        ticks[cache.tick].previousTick, 
                        cache.nextTick,
                        0,0,0,0,0
                    );
                    ticks[ticks[cache.tick].previousTick].nextTick  = nextLatestTick;
                    ticks[cache.nextTick].previousTick              = nextLatestTick;
                    delete ticks[latestTick];
                } else {
                    ticks[nextLatestTick] = Tick(
                        cache.tick, 
                        cache.nextTick,
                        0,0,0,0,0
                    );
                    ticks[cache.tick].nextTick = nextLatestTick;
                    ticks[cache.nextTick].previousTick = nextLatestTick;
                }
            }
            nearestTick = nextLatestTick;
        // handle TWAP moving down
        } else if (nextLatestTick < latestTick) {
            // save current liquidity and set liquidity to zero
            ticks[latestTick].liquidityDelta += int128(liquidity);
            liquidity = 0;
            cache.nextTick = ticks[nearestTick].previousTick;
            while (cache.nextTick > nextLatestTick) {
                (
                    , 
                    cache.tick,
                    cache.nextTick
                ) = Ticks.cross(
                    ticks,
                    cache.tick,
                    cache.nextTick,
                    0,
                    true
                );
            }
            console.log('cross to next latest tick:');
            console.logInt(cache.tick);
            console.logInt(cache.nextTick);
            // if tick doesn't exist currently
            //TODO: if tick is deleted rollover amounts if necessary
            //TODO: do we recalculate deltas if liquidity is removed?
            if (ticks[nextLatestTick].previousTick == 0 && ticks[nextLatestTick].nextTick == 0){
                //TODO: can we assume this is always MIN_TICK?
                ticks[nextLatestTick] = Tick(
                        cache.nextTick, 
                        cache.tick,
                        0,0,0,0,0
                );
                ticks[cache.tick].nextTick = nextLatestTick;
                ticks[cache.nextTick].previousTick = nextLatestTick;
            }
        }

        console.log('cross last tick touched');
        console.logInt(cache.tick);
        console.logInt(ticks[cache.tick].nextTick);

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
        // console.logInt(ticks[cache.nextTick].previousTick);
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
        bool zeroForOne,
        int128 amount
    ) internal {
        // load position into memory
        Position memory position = zeroForOne ? positions0[owner][lower][upper] : positions1[owner][lower][upper];
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
                    int128 amountInDelta = ticks[claim].amountInDelta;
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
                    int128 amountOutDelta = ticks[claim].amountOutDelta;
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
