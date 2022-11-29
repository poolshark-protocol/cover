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


        //TODO: validate observationCardinalityNext

        // set default initial values
        latestTick = utils.calculateAverageTick(IConcentratedPool(inputPool));
        ticks[latestTick] = Tick(
           TickMath.MIN_TICK, TickMath.MAX_TICK, 
            0,0,
            0,0,0
        );
        // if latestTick != MIN_TICK
        ticks[TickMath.MIN_TICK] = Tick(
            TickMath.MIN_TICK, latestTick, 
            0,0,
            0,0,0
        );
        // if latestTick != MAX_TICK
        ticks[TickMath.MAX_TICK] = Tick(
            latestTick, TickMath.MAX_TICK, 
            0,0,
            0,0,0
        );
        nearestTick = latestTick;
        // console.log("starting latestTick:");
        // console.logInt(int256(nearestTick));
        sqrtPrice = TickMath.getSqrtRatioAtTick(nearestTick);
        unlocked = 1;
        lastBlockNumber = uint32(block.number);
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        _ensureTickSpacing(mintParams.lower, mintParams.upper);

        if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
        if (mintParams.lower >= mintParams.upper) { revert InvalidPosition(); }

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
        }

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        uint256 currentPrice;
        uint256 priceEntry;

        //TODO: liquidity cannot be added to the current tick 

        currentPrice = uint256(sqrtPrice);
        if (priceUpper <= currentPrice) { revert InvalidPosition(); }
        if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
        //TODO: handle priceLower < currentPrice
        priceEntry = priceLower;

        console.log("amount of tokens added:", mintParams.amountDesired);

        //TODO: given upper, lower, and amount, solve for other amount
        liquidityMinted = utils.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            priceUpper,
            uint256(mintParams.amountDesired),
            0
        );

        if(!mintParams.zeroForOne){
            _transferIn(tokenOut, mintParams.amountDesired);
        } else {
            revert NotImplementedYet();
        }
        console.log("amount of liquidity minted:", liquidityMinted);

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert Overflow();

        _updateSecondsPerLiquidity(uint256(liquidity));

        unchecked {
            _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                mintParams.lower,
                int128(uint128(liquidityMinted))
            );
            // liquidity should always be out of range initially
            if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity += uint128(liquidityMinted);
        }

        nearestTick = Ticks.insert(
            ticks,
            feeGrowthGlobal,
            secondsGrowthGlobal,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            nearestTick,
            latestTick,
            uint160(currentPrice)
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

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
        }

        _updateSecondsPerLiquidity(uint256(liquidity));

        // only remove liquidity if lower if below currentPrice
        unchecked {
            if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity -= amount;
        }

        // handle liquidity withdraw and transfer out in _updatePosition

        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert Overflow();

        // _updatePosition(msg.sender, lower, upper, -int128(amount));
        (tokenInAmount, tokenOutAmount) = _updatePosition(
            msg.sender,
            lower,
            upper,
            claim,
            -int128(amount)
        );

        uint256 amountIn;
        uint256 amountOut;

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

    function _updateSecondsPerLiquidity(uint256 currentLiquidity) internal {
        unchecked {
            uint256 diff = block.number - uint256(lastBlockNumber);
            if (diff > 0 && currentLiquidity > 0) {
                lastBlockNumber = uint32(block.number); // Overfyarnlow in 2106. Don't do staking rewards in the year 2106.
                secondsGrowthGlobal += uint160((diff << 128) / currentLiquidity);
            }
        }
    }

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

        if(block.number != lastBlockNumber) {
            console.log("accumulating last block");
            _accumulateLastBlock();
            console.logInt(ticks[50].previousTick);
            console.logInt(ticks[30].previousTick);
            console.logInt(ticks[20].previousTick);
            console.logInt(ticks[0].previousTick);
        }

        SwapCache memory cache = SwapCache({
            feeAmount: 0,
            totalFeeAmount: 0,
            protocolFee: 0,
            feeGrowthGlobal: feeGrowthGlobal,
            currentTick: nearestTick,
            currentPrice: uint256(sqrtPrice),
            currentLiquidity: uint256(liquidity),
            input: amountIn,
            nextTickToCross: ticks[nearestTick].previousTick
        });

        console.log('starting tick:');
        console.logInt(cache.currentTick);
        console.log("liquidity:", cache.currentLiquidity);
        console.logInt(cache.nextTickToCross);

        _updateSecondsPerLiquidity(cache.currentLiquidity);

        uint256 output = 0;

        while (cache.input != 0) {
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
                    output = utils.getDy(cache.currentLiquidity, newSqrtPrice, cache.currentPrice, false);
                    console.log("dtokenOut:", output);
                    cache.currentPrice= newSqrtPrice;
                    //TODO: should be current tick
                    ticks[cache.nextTickToCross].amountIn += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Execute swap step and cross the tick.
                    console.log('nextsqrtprice:', nextSqrtPrice);
                    console.log('currentprice:', cache.currentPrice);
                    output = utils.getDy(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);
                    console.log("dtokenOut:", output);
                    cache.currentPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[cache.currentTick].amountIn += uint128(maxDx);
                    cache.input -= maxDx;
                }
            } else {
                revert NotImplementedYet();
            }

            console.log("liquidity:", cache.currentLiquidity);
            // cache.feeGrowthGlobal is the feeGrowthGlobal counter for the output token.
            // It increases each swap step.
            (cache.totalFeeAmount, amountOut, cache.protocolFee, cache.feeGrowthGlobal) = utils.handleFees(
                output,
                swapFee,
                cache.currentLiquidity,
                cache.totalFeeAmount,
                amountOut,
                cache.protocolFee,
                cache.feeGrowthGlobal
            );
            if (cross) {
                console.log('crossing tick');
                console.logInt(cache.currentTick);
                console.logInt(cache.nextTickToCross);
                (cache.currentLiquidity, cache.currentTick, cache.nextTickToCross) = Ticks.cross(
                    ticks,
                    cache.currentTick,
                    cache.nextTickToCross,
                    secondsGrowthGlobal,
                    cache.currentLiquidity,
                    cache.feeGrowthGlobal,
                    true,
                    tickSpacing
                );
                if (cache.currentLiquidity == 0) {
                    // We step into a zone that has liquidity - or we reach the end of the linked list.
                    // console.log("current tick:");
                    // console.logInt(cache.currentTick);
                    console.log('out of liquidity');
                    if(cache.currentTick == TickMath.MIN_TICK) break;
                    cache.currentPrice = uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
                    (cache.currentLiquidity, cache.currentTick, cache.nextTickToCross) = Ticks.cross(
                        ticks,
                        cache.currentTick,
                        cache.nextTickToCross,
                        secondsGrowthGlobal,
                        cache.currentLiquidity,
                        cache.feeGrowthGlobal,
                        true,
                        tickSpacing
                    );
                }
                if(cache.currentPrice == sqrtPriceLimitX96) break;
            } else {
                // console.log("breaking");
                break;
            }
        }

        if (zeroForOne){
            sqrtPrice = uint160(cache.currentPrice);
            int24 newNearestTick = cache.nextTickToCross;
            if(nearestTick != newNearestTick){
                nearestTick = newNearestTick;
                liquidity = uint128(cache.currentLiquidity);
            }
        } else {
            revert NotImplementedYet();
        }

        console.log('fee growth:', cache.feeGrowthGlobal);
        console.log('output:');
        console.log(amountOut);
        console.log('new price:', sqrtPrice);
        console.log('current tick:');
        console.log(cache.currentLiquidity);
        console.logInt( cache.currentTick);
        console.log('new nearest tick:');
        console.logInt(nearestTick);
        _updateFees(zeroForOne, cache.feeGrowthGlobal, uint128(cache.protocolFee));

        if (zeroForOne) {
            console.log('tokenOut balance before:', ERC20(tokenOut).balanceOf(address(this)));
            _transferOut(recipient, tokenOut, amountOut);
            console.log('tokenOut balance after:', ERC20(tokenOut).balanceOf(address(this)));
            emit Swap(recipient, tokenIn, tokenOut, amountIn, amountOut);
        } else {
            _transferOut(recipient, tokenIn, amountOut);
            emit Swap(recipient, tokenOut, tokenIn, amountIn, amountOut);
        }
    }

    /// @dev Collects fees for Poolshark protocol.
    function collectProtocolFee() public lock returns (uint128 amountIn, uint128 amountOut) {
        if (tokenInProtocolFee > 1) {
            amountIn = tokenInProtocolFee - 1;
            tokenInProtocolFee = 1;
            _transferOut(feeTo, tokenIn, amountIn);
        }
        if (tokenOutProtocolFee > 1) {
            amountOut = tokenOutProtocolFee - 1;
            tokenOutProtocolFee = 1;
            _transferOut(feeTo, tokenOut, amountOut);
        }
    }

    function _ensureTickSpacing(int24 lower, int24 upper) internal view {
        if (lower % int24(tickSpacing) != 0) revert InvalidTick();
        //TODO: is LowerEven needed for this protocol?
        if ((lower / int24(tickSpacing)) % 2 != 0) revert LowerEven();
        if (upper % int24(tickSpacing) != 0) revert InvalidTick();
        if ((upper / int24(tickSpacing)) % 2 == 0) revert UpperOdd();
    }

    function getAmountIn(bytes calldata data) internal view returns (uint256 finalAmountIn) {
        // TODO: make override
        (address tokenOut, uint256 amountOut) = abi.decode(data, (address, uint256));
        uint256 amountOutWithoutFee = (amountOut * 1e6) / (1e6 - swapFee) + 1;
        uint256 currentPrice = uint256(sqrtPrice);
        int24 nextTickToCross = tokenOut == tokenOut ? nearestTick : ticks[nearestTick].nextTick;
        int24 nextTick;

        finalAmountIn = 0;
        while (amountOutWithoutFee != 0) {
            uint256 nextTickPrice = uint256(TickMath.getSqrtRatioAtTick(nextTickToCross));
            if (tokenOut == tokenOut) {
                uint256 currentLiquidity = uint256(liquidity);
                uint256 maxDy = utils.getDy(currentLiquidity, nextTickPrice, currentPrice, false);
                if (amountOutWithoutFee <= maxDy) {
                    unchecked {
                        amountOut = (amountOut * 1e6) / (1e6 - swapFee) + 1;
                    }
                    uint256 newPrice = currentPrice - utils.mulDiv(amountOut, 0x1000000000000000000000000, currentLiquidity);
                    finalAmountIn += (utils.getDx(currentLiquidity, newPrice, currentPrice, false) + 1);
                    // finalAmountIn += amountOut/currentPrice/newPrice  TODO: equal?
                    break;
                } else {
                    finalAmountIn += utils.getDx(currentLiquidity, nextTickPrice, currentPrice, false);
                    unchecked {
                        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                            currentLiquidity -= ticks[nextTickToCross].liquidity;
                        } else {
                            currentLiquidity += ticks[nextTickToCross].liquidity;
                        }
                        amountOutWithoutFee -= maxDy;
                        amountOutWithoutFee += 1; // to compensate rounding issues
                        uint256 feeAmount = utils.mulDivRoundingUp(maxDy, swapFee, 1e6);
                        if (amountOut <= (maxDy - feeAmount)) break;
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
                    break;
                } else {
                    // Swap & cross the tick.
                    finalAmountIn += utils.getDy(currentLiquidity, currentPrice, nextTickPrice, false);
                    unchecked {
                        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                            currentLiquidity += ticks[nextTickToCross].liquidity;
                        } else {
                            currentLiquidity -= ticks[nextTickToCross].liquidity;
                        }
                        amountOutWithoutFee -= maxDx;
                        amountOutWithoutFee += 1; // to compensate rounding issues
                        uint256 feeAmount = utils.mulDivRoundingUp(maxDx, swapFee, 1e6);
                        if (amountOut <= (maxDx - feeAmount)) break;
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
    }

    function _transferBothTokens(
        address to,
        uint256 shares0,
        uint256 shares1
    ) internal {
        _transferOut(to, tokenIn, shares0);
        _transferOut(to, tokenOut, shares1);
    }

    function _updateFees(
        bool zeroForOne,
        uint256 feeGrowthGlobal,
        uint128 protocolFee
    ) internal {
        if (zeroForOne) {
            feeGrowthGlobal = feeGrowthGlobal;
            tokenOutProtocolFee += protocolFee;
        } else {
            feeGrowthGlobal = feeGrowthGlobal;
            tokenInProtocolFee += protocolFee;
        }
    }
    //TODO: zap into LP position
    //TODO: use bitmaps to naiively search for the tick closest to the new TWAP
    //TODO: assume everything will get filled for now
    //TODO: remove old latest tick if necessary
    //TODO: after accumulation, all liquidity below old latest tick is removed
    function _accumulateLastBlock() internal {
        console.log("-- START ACCUMULATE LAST BLOCK --");
        // get the next price update
        uint256 oldLatestTickPrice; int24 nextLatestTick;
        {
            nextLatestTick = utils.calculateAverageTick(IConcentratedPool(inputPool));
            oldLatestTickPrice = uint256(TickMath.getSqrtRatioAtTick(latestTick));
        }

        console.log('starting tick');
        console.logInt(nearestTick);

        console.log('next latest tick');
        console.logInt(nextLatestTick);

        AccumulateCache memory cache = AccumulateCache({
            currentTick: nearestTick,
            currentPrice: sqrtPrice,
            currentLiquidity: uint256(liquidity),
            amountIn: 0,
            nextTickToCross: ticks[nearestTick].nextTick,
            feeGrowthGlobal: feeGrowthGlobal
        });
        console.log('next tick');
        console.logInt(ticks[cache.currentTick].nextTick);
        while(cache.currentPrice < oldLatestTickPrice) {
            // carry over amountIn
            (
              cache.currentLiquidity, 
              cache.currentTick,
              cache.nextTickToCross, 
              cache.amountIn
            ) = Ticks.accumulate(
                ticks,
                cache.currentTick,
                cache.nextTickToCross,
                cache.currentLiquidity,
                tickSpacing,
                swapFee
            );
            cache.currentPrice = TickMath.getSqrtRatioAtTick(cache.currentTick);
            // repeat until we capture everything up to the previous TWAP
        }

        console.log('accumulate last tick touched');
        console.logInt(cache.currentTick);
        console.logInt(cache.nextTickToCross);

        // iterate to new latest tick
        while (cache.nextTickToCross < nextLatestTick) {
            // only iterate to the new TWAP and update liquidity
            (cache.currentLiquidity, cache.currentTick, cache.nextTickToCross) = Ticks.cross(
                ticks,
                cache.currentTick,
                cache.nextTickToCross,
                secondsGrowthGlobal,
                cache.currentLiquidity,
                feeGrowthGlobal,
                false,
                tickSpacing
            );
            console.log('next tick after');
            console.logInt(cache.currentTick);
            console.logInt(ticks[cache.currentTick].nextTick);
            console.log('liquidity:', cache.currentLiquidity);
        }

        console.log('cross last tick touched');
        console.logInt(cache.currentTick);
        console.logInt(ticks[cache.currentTick].nextTick );

        // insert new latest tick
        if (cache.currentTick != nextLatestTick) {
            ticks[nextLatestTick] = Tick(
                cache.currentTick, cache.nextTickToCross, 
                0,0,
                0,0,0
            );
            ticks[cache.currentTick].nextTick         = nextLatestTick;
            ticks[cache.nextTickToCross].previousTick = nextLatestTick;

            latestTick = nextLatestTick;
            nearestTick = nextLatestTick;
            sqrtPrice = TickMath.getSqrtRatioAtTick(nextLatestTick);
        }


        // insert new latest tick
        console.log('updated tick after insert');
        console.logInt(ticks[cache.nextTickToCross].previousTick);
        console.log("-- END ACCUMULATE LAST BLOCK --");

        lastBlockNumber = block.number;
    }

    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        int24 claim,
        int128 amount
    ) internal returns (uint128 amountInClaimable, uint128 amountOutClaimable) {
        // load position into memory
        Position memory position = positions[owner][lower][upper];
        // validate removal amount is less than position liquidity
        // console.log("position liquidity:", position.liquidity);
        // console.log(uint128(-amount));
        if (amount < 0 && uint128(-amount) > position.liquidity) revert NotEnoughPositionLiquidity();

        uint256 priceLower   = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper   = uint256(TickMath.getSqrtRatioAtTick(upper));
        uint256 claimPrice   = uint256(TickMath.getSqrtRatioAtTick(claim));

        // user cannot claim twice from the same part of the curve
        if (position.claimPriceLast > claimPrice) revert InvalidClaimTick();

        // handle claims
        if(ticks[claim].feeGrowthGlobal > position.feeGrowthGlobalLast) {
            // skip claim if lower == claim
            if(claim != lower){
                // calculate what is claimable
                {
                    (uint256 amountInTotal,)   = utils.getAmountsForLiquidity(priceLower, priceUpper, claimPrice, position.liquidity, false);
                    (uint256 amountInClaimed,) = utils.getAmountsForLiquidity(priceLower, priceUpper, position.claimPriceLast, uint128(amount), false);
                    amountInClaimable  = uint128(amountInTotal  - amountInClaimed) * (1e6 + swapFee) / 1e6; //factors in fees
                }
                // verify user passed highest tick with growth
                if (claim != upper){
                    {
                        // next tick should not have any fee growth
                        int24 claimNextTick = ticks[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobal > position.feeGrowthGlobalLast) revert WrongTickClaimedAt();
                    }
                }
                // update amounts claimable at tick
                ticks[claim].amountIn  -= uint128(amountInClaimable);

                //TODO: store in position or transfer to user?
                // update position values
                position.amountIn      += amountInClaimable;
                position.claimPriceLast = uint160(claimPrice);
                position.feeGrowthGlobalLast = feeGrowthGlobal;
            }
        } else if (position.claimPriceLast == 0) {
            position.claimPriceLast = uint160(priceLower);
        }

        // update liquidity at claim tick
        if (amount < 0) {
            // calculate amount to transfer out
            // if claimPrice is lower, pass priceUpper
            // somehow we have to do the inverse side of the curve
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
