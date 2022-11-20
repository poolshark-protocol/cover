// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./interfaces/IPoolsharkHedgePool.sol";
import "./interfaces/IPositionManager.sol";
import "./base/PoolsharkHedgePoolStorage.sol";
import "./base/PoolsharkHedgePoolView.sol";
import "./base/PoolsharkHedgePoolEvents.sol";
import "./libraries/FullPrecisionMath.sol";
import "./libraries/UnsafeMath.sol";
import "./libraries/DyDxMath.sol";
import "./libraries/SwapLib.sol";
import "./libraries/Ticks.sol";
import "./libraries/SafeTransfers.sol";
import "./base/oracle/TwapOracle.sol";
import "./utils/PoolsharkErrors.sol";

/// @notice Trident Concentrated liquidity pool implementation.
/// @dev SafeTransfers contains PoolsharkHedgePoolErrors
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkHedgePoolView,
    PoolsharkTicksErrors,
    PoolsharkPositionErrors,
    SafeTransfers,
    TwapOracle
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

    using Ticks for mapping(int24 => Tick);

    constructor(bytes memory _poolParams) {
        (
            address _factory,
            address _inputPool,
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
                uint24,
                uint24,
                bool
            )
        );

        // check for invalid params
        if (_tokenIn == address(0) || _tokenIn == address(this)) revert InvalidToken();
        if (_tokenOut == address(0) || _tokenOut == address(this)) revert InvalidToken();
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = _factory;
        inputPool   = _inputPool;
        tokenIn     = _lpZeroForOne ? _tokenOut : _tokenIn;
        tokenOut    = _lpZeroForOne ? _tokenIn : _tokenOut;
        swapFee     = _swapFee;
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(_factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);
        ticks[TickMath.MIN_TICK] = Tick(
            TickMath.MIN_TICK, TickMath.MAX_TICK, 
            0, 0,
            0,0,0,
            0,
            0,
            0
        );
        ticks[TickMath.MAX_TICK] = Tick(
            TickMath.MIN_TICK, TickMath.MAX_TICK, 
            0, 0,
            0,0,0,
            0,
            0,
            0
        );

        //TODO: validate observationCardinalityNext

        // set default initial values
        nearestTick = calculateAverageTick(IConcentratedPool(inputPool));
        sqrtPrice = TickMath.getSqrtRatioAtTick(nearestTick);
        unlocked = 1;
        lastObservation = uint32(block.timestamp);
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        _ensureTickSpacing(mintParams.lower, mintParams.upper);

        if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
        if (mintParams.lower >= mintParams.upper) { revert InvalidPosition(); }

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        uint256 currentPrice;
        uint256 priceEntry;

        //TODO: liquidity cannot be added to the current tick 

        currentPrice = uint256(sqrtPrice);
        if (priceUpper <= currentPrice) { revert InvalidPosition(); }
        if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
        priceEntry = priceUpper;

        liquidityMinted = DyDxMath.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            currentPrice,
            0,
            uint256(mintParams.amountDesired)
        );

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
            uint160(currentPrice)
        );

        (uint128 amountInActual, uint128 amountOutActual) = DyDxMath.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            priceEntry,
            liquidityMinted,
            true
        );

        IPositionManager(msg.sender).mintCallback(tokenIn, tokenOut, amountInActual, amountOutActual, mintParams.native);

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
            uint256 diff = block.timestamp - uint256(lastObservation);
            if (diff > 0 && currentLiquidity > 0) {
                lastObservation = uint32(block.timestamp); // Overfyarnlow in 2106. Don't do staking rewards in the year 2106.
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

        if(block.timestamp != lastBlockTimestamp) {
            _accumulateLastBlock();
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
            nextTickToCross: ticks[nearestTick].nextTick
        });

        _updateSecondsPerLiquidity(cache.currentLiquidity);

        while (cache.input != 0) {
            uint256 nextTickSqrtPrice = uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
            uint256 nextSqrtPrice = nextTickSqrtPrice;
            uint256 output = 0;
            bool cross = false;

            if (zeroForOne) {
                // Trading token 0 (x) for token 1 (y).
                // sqrtPrice  is decreasing.
                // Maximum input amount within current tick range: Δx = Δ(1/√𝑃) · L.
                if (nextSqrtPrice < sqrtPriceLimitX96) { nextSqrtPrice = sqrtPriceLimitX96; }
                uint256 maxDx = DyDxMath.getDx(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);

                if (cache.input <= maxDx) {
                    // We can swap within the current range.
                    uint256 liquidityPadded = cache.currentLiquidity << 96;
                    // Calculate new sqrtPriceafter swap: √𝑃[new] =  L · √𝑃 / (L + Δx · √𝑃)
                    // This is derived from Δ(1/√𝑃) = Δx/L
                    // where Δ(1/√𝑃) is 1/√𝑃[old] - 1/√𝑃[new] and we solve for √𝑃[new].
                    // In case of an overflow we can use: √𝑃[new] = L / (L / √𝑃 + Δx).
                    // This is derived by dividing the original fraction by √𝑃 on both sides.
                    uint256 newSqrtPrice = uint256(
                        FullPrecisionMath.mulDivRoundingUp(liquidityPadded, cache.currentPrice, liquidityPadded + cache.currentPrice * cache.input)
                    );

                    if (!(nextSqrtPrice <= newSqrtPrice && newSqrtPrice < cache.currentPrice)) {
                        // Overflow. We use a modified version of the formula.
                        newSqrtPrice = uint160(UnsafeMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.currentPrice+ cache.input));
                    }
                    // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                    output = DyDxMath.getDy(cache.currentLiquidity, newSqrtPrice, cache.currentPrice, false);
                    cache.currentPrice= newSqrtPrice;
                    //TODO: should be current tick
                    ticks[cache.nextTickToCross].amountInGrowth += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Execute swap step and cross the tick.
                    output = DyDxMath.getDy(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);
                    cache.currentPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[cache.currentTick].amountInGrowth += uint128(maxDx);
                    cache.input -= maxDx;
                }
            } else {
                revert NotImplementedYet();
            }

            // cache.feeGrowthGlobal is the feeGrowthGlobal counter for the output token.
            // It increases each swap step.
            (cache.totalFeeAmount, amountOut, cache.protocolFee, cache.feeGrowthGlobal) = SwapLib.handleFees(
                output,
                swapFee,
                cache.currentLiquidity,
                cache.totalFeeAmount,
                amountOut,
                cache.protocolFee,
                cache.feeGrowthGlobal
            );
            if (cross) {
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
                    cache.currentPrice= uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
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
            } else {
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

        _updateFees(zeroForOne, cache.feeGrowthGlobal, uint128(cache.protocolFee));

        if (zeroForOne) {
            _transferOut(recipient, tokenOut, amountOut);
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
                uint256 maxDy = DyDxMath.getDy(currentLiquidity, nextTickPrice, currentPrice, false);
                if (amountOutWithoutFee <= maxDy) {
                    unchecked {
                        amountOut = (amountOut * 1e6) / (1e6 - swapFee) + 1;
                    }
                    uint256 newPrice = currentPrice - FullPrecisionMath.mulDiv(amountOut, 0x1000000000000000000000000, currentLiquidity);
                    finalAmountIn += (DyDxMath.getDx(currentLiquidity, newPrice, currentPrice, false) + 1);
                    // finalAmountIn += amountOut/currentPrice/newPrice  TODO: equal?
                    break;
                } else {
                    finalAmountIn += DyDxMath.getDx(currentLiquidity, nextTickPrice, currentPrice, false);
                    unchecked {
                        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                            currentLiquidity -= ticks[nextTickToCross].liquidity;
                        } else {
                            currentLiquidity += ticks[nextTickToCross].liquidity;
                        }
                        amountOutWithoutFee -= maxDy;
                        amountOutWithoutFee += 1; // to compensate rounding issues
                        uint256 feeAmount = FullPrecisionMath.mulDivRoundingUp(maxDy, swapFee, 1e6);
                        if (amountOut <= (maxDy - feeAmount)) break;
                        amountOut -= (maxDy - feeAmount);
                    }
                    nextTick = ticks[nextTickToCross].previousTick;
                }
            } else {
                uint256 currentLiquidity = uint256(liquidity);
                uint256 maxDx = DyDxMath.getDx(currentLiquidity, currentPrice, nextTickPrice, false);

                if (amountOutWithoutFee <= maxDx) {
                    unchecked {
                        amountOut = (amountOut * 1e6) / (1e6 - swapFee) + 1;
                    }
                    uint256 liquidityPadded = currentLiquidity << 96;
                    uint256 newPrice = uint256(
                        FullPrecisionMath.mulDivRoundingUp(liquidityPadded, currentPrice, liquidityPadded - currentPrice * amountOut)
                    );
                    if (!(currentPrice < newPrice && newPrice <= nextTickPrice)) {
                        // Overflow. We use a modified version of the formula.
                        newPrice = uint160(UnsafeMath.divRoundingUp(liquidityPadded, liquidityPadded / currentPrice - amountOut));
                    }
                    finalAmountIn += (DyDxMath.getDy(currentLiquidity, currentPrice, newPrice, false) + 1);
                    break;
                } else {
                    // Swap & cross the tick.
                    finalAmountIn += DyDxMath.getDy(currentLiquidity, currentPrice, nextTickPrice, false);
                    unchecked {
                        if ((nextTickToCross / int24(tickSpacing)) % 2 == 0) {
                            currentLiquidity += ticks[nextTickToCross].liquidity;
                        } else {
                            currentLiquidity -= ticks[nextTickToCross].liquidity;
                        }
                        amountOutWithoutFee -= maxDx;
                        amountOutWithoutFee += 1; // to compensate rounding issues
                        uint256 feeAmount = FullPrecisionMath.mulDivRoundingUp(maxDx, swapFee, 1e6);
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

    function _accumulateLastBlock() internal {
        // start from the current nearest tick
        AccumulateCache memory cache = AccumulateCache({
            feeGrowthGlobal: ticks[nearestTick].feeGrowthGlobal,
            currentTick: ticks[nearestTick].nextTick,
            prevTick: nearestTick,
            currentPrice: uint256(TickMath.getSqrtRatioAtTick(ticks[nearestTick].previousTick)),
            nextPrice: uint256(sqrtPrice),
            currentLiquidity: uint256(liquidity),
            amountIn: 0,
            amountOut: 0,
            amountInUnfilled: 0
        });
        uint128 amountInUnfilled; int24 stopTick; int24 nextTickUpdate;
        {
            uint256 currentPrice = uint256(TickMath.getSqrtRatioAtTick(ticks[nearestTick].previousTick));
            cache.amountInUnfilled = uint128(DyDxMath.getDy(cache.currentLiquidity, cache.nextPrice, currentPrice, false));
            
            // update the TWAP with the most current
            // if TWAP moves up then we need to accumulate everything up to that
            // if TWAP moves down there is no need to do anything
            stopTick = latestTick;
            nextTickUpdate = calculateAverageTick(IConcentratedPool(inputPool));

            if (nextTickUpdate > latestTick){
                stopTick = nextTickUpdate;
            }
        }

        while(cache.currentTick <= stopTick) {
             // take amountInPending
            // push it to the previous tick
            // carry over based on percent of liquidity between the two ticks
            uint128 carryPercent = 1e18 - (ticks[cache.currentTick].liquidity * 1e18) / ticks[cache.prevTick].liquidity;
            uint128 amountInGrowthDiff  = ticks[cache.prevTick].amountInGrowthLast - ticks[cache.prevTick].amountInGrowth;
            uint128 amountInCarryover = uint128(amountInGrowthDiff * carryPercent / 1e18);
            uint128 amountOutCarryover = amountInUnfilled / ticks[cache.prevTick].amountIn * ticks[cache.prevTick].amountOut;
            //TODO: keep going to next tick until carryPercent isn't 1e18
            if (carryPercent < 1e18) {
                ticks[cache.currentTick].amountIn  += amountInCarryover;
                ticks[cache.currentTick].amountOut += amountOutCarryover;
            }
            ticks[cache.prevTick].amountIn  -= amountInCarryover;
            ticks[cache.prevTick].amountOut -= amountOutCarryover;
            ticks[cache.prevTick].amountInGrowthLast += amountInGrowthDiff;

            cache.amountIn  += amountInCarryover; 
            cache.amountOut += amountOutCarryover;

            if (cache.currentTick > latestTick) {
                uint256 latestTickPrice     = TickMath.getSqrtRatioAtTick(latestTick);
                uint256 nextTickUpdatePrice = TickMath.getSqrtRatioAtTick(nextTickUpdate);
                amountInUnfilled += uint128(DyDxMath.getDy(cache.currentLiquidity, latestTickPrice, nextTickUpdatePrice, false));
            }

            // zero out liquidity because everything has been filled
            ticks[cache.prevTick].liquidity = 0;

            cache.prevTick = cache.currentTick;
            cache.currentTick = ticks[cache.currentTick].nextTick;
            // handle liquidity removal and add with +/-
            // + -> upper tick of DAI liquidity curve
            // - -> lower tick of DAI liquidity curve
            cache.currentLiquidity -= ticks[cache.currentTick].liquidity;
            
            // repeat until we capture everything up to the previous TWAP
        }

        // once current tick is crossed, all liquidity is removed
        ticks[cache.prevTick].liquidity = uint128(cache.currentLiquidity);
        
        ticks[cache.prevTick].amountInUnfilled = amountInUnfilled;

        nearestTick = nextTickUpdate;
        sqrtPrice = TickMath.getSqrtRatioAtTick(nextTickUpdate);

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
        if (amount < 0 && uint128(amount) > position.liquidity) revert NotEnoughPositionLiquidity();

        uint256 priceLower   = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper   = uint256(TickMath.getSqrtRatioAtTick(upper));
        uint256 claimPrice   = uint256(TickMath.getSqrtRatioAtTick(claim));

        // user cannot claim twice from the same part of the curve
        if (claimPrice <= position.claimPriceLast) revert InvalidClaimTick();

        // handle claims
        if(ticks[claim].feeGrowthGlobal > position.feeGrowthGlobalLast) {
            // skip claim if lower == claim
            if(claim != lower){
                // calculate what is claimable
                {
                    (uint256 amountInTotal,)     = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, claimPrice, position.liquidity, false);
                    (uint256 amountInClaimed,) = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, position.claimPriceLast, uint128(amount), false);
                    amountInClaimable  = uint128(amountInTotal  - amountInClaimed); //TODO: factor in fees as well
                    uint128 amountInUnfilled = amountInClaimable * uint128(ticks[claim].amountInUnfilled * 1e18 / ticks[claim].amountIn) / 1e18;
                    amountInClaimable -= amountInUnfilled;
                    amountOutClaimable = amountInClaimable * 1e18 / ticks[claim].amountIn * ticks[claim].amountOut / 1e18;
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
                ticks[claim].amountOut -= uint128(amountOutClaimable);

                //TODO: store in position or transfer to user?
                // update position values
                position.amountIn      += amountInClaimable;
                position.amountOut     += amountOutClaimable;
                position.claimPriceLast = uint160(claimPrice);
                position.feeGrowthGlobalLast = feeGrowthGlobal;
            }
        }

        // update liquidity at claim tick
        if (amount < 0) {
            // calculate amount to transfer out
            ( , uint256 amountOutRemoved)     = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, claimPrice, uint128(amount), false);
            // will underflow if too much liquidity withdrawn
            uint128 liquidityAmount = uint128(-amount);
            position.liquidity -= liquidityAmount;
            // liquidity now needs to be removed at claim tick
            if (sqrtPrice < claimPrice) { ticks[claim].liquidity += liquidityAmount; }
            // liquidity at upper tick need not be removed anymore
            ticks[upper].liquidity -= liquidityAmount;
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
            if(position.liquidity > 0) revert NotImplementedYet();
            position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }

        positions[owner][lower][upper] = position;
    }
}
