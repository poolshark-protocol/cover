// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/IPoolsharkHedgePool.sol";
import "./interfaces/IPositionManager.sol";
import "./base/PoolsharkHedgePoolStorage.sol";
import "./base/PoolsharkHedgePoolView.sol";
import "./base/PoolsharkHedgePoolEvents.sol";
import "./libraries/FullPrecisionMath.sol";
import "./libraries/TickMath.sol";
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
            0, 0,
            0,
            0,
            0
        );
        ticks[TickMath.MAX_TICK] = Tick(
            TickMath.MIN_TICK, TickMath.MAX_TICK, 
            0, 0,
            0, 0,
            0,
            0,
            0
        );

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

        // calculate liquidity minted
        if(mintParams.zeroForOne){
            // position upper should be above current price


            // unchecked {
            //     // liquidity should always be out of range initially
            //     if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity += uint128(liquidityMinted);
            // }

            // Ticks.insert(
            //     ticks,
            //     feeGrowthGlobal0,
            //     feeGrowthGlobal1,
            //     secondsGrowthGlobal,
            //     mintParams.lowerOld,
            //     mintParams.lower,
            //     mintParams.upperOld,
            //     mintParams.upper,
            //     uint128(liquidityMinted),
            //     nearestTick0,
            //     uint160(currentPrice)
            // );
            // if tick is in range of the current TWAP, update nearestTick0/1
        } else {
            // position upper should be lower than current price
            currentPrice = uint256(sqrtPrice);
            if (priceLower >= currentPrice) { revert InvalidPosition(); }
            if (mintParams.amountDesired == 0) { revert InvalidPosition(); }
            priceEntry = priceLower;

            liquidityMinted = DyDxMath.getLiquidityForAmounts(
                priceLower,
                priceUpper,
                currentPrice,
                uint256(mintParams.amountDesired),
                0
            );

            _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                mintParams.lower,
                int128(uint128(liquidityMinted))
            );

            // unchecked {
            //     // liquidity should always be out of range initially
            //     if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity += uint128(liquidityMinted);
            // }

            // Ticks.insert(
            //     ticks,
            //     feeGrowthGlobal0,
            //     feeGrowthGlobal1,
            //     secondsGrowthGlobal,
            //     mintParams.lowerOld,
            //     mintParams.lower,
            //     mintParams.upperOld,
            //     mintParams.upper,
            //     uint128(liquidityMinted),
            //     nearestTick0,
            //     uint160(currentPrice)
            // );
        }

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert Overflow();

        // _updateSecondsPerLiquidity(uint256(liquidity));

        unchecked {
            
            // if (amountInFees > 0) {
            //     _transferOut(msg.sender, tokenIn, amountIn);
            // }
            // if (amountOutFees > 0) {
            //     _transferOut(msg.sender, tokenOut, amountOut);
            // }

            // if (priceLower <= currentPrice && currentPrice < priceUpper) liquidity += uint128(liquidityMinted);
        }
        

        //TODO: handle with new Tick struct

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
        uint128 amount
    )
        public
        lock
        returns (
            uint256 tokenInAmount,
            uint256 tokenOutAmount,
            uint256 tokenInFees,
            uint256 tokenOutFees
        )
    {
        uint160 priceLower = TickMath.getSqrtRatioAtTick(lower);
        uint160 priceUpper = TickMath.getSqrtRatioAtTick(upper);
        uint160 currentPrice= sqrtPrice;

        _updateSecondsPerLiquidity(uint256(liquidity));

        unchecked {
            if (priceLower <= currentPrice&& currentPrice< priceUpper) liquidity -= amount;
        }

        (tokenInAmount, tokenOutAmount) = DyDxMath.getAmountsForLiquidity(
            uint256(priceLower),
            uint256(priceUpper),
            uint256(currentPrice),
            uint256(amount),
            false
        );

        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert Overflow();

        // (tokenInFees, tokenOutFees) = _updatePosition(msg.sender, lower, upper, -int128(amount));

        uint256 amountIn;
        uint256 amountOut;

        unchecked {
            amountIn = tokenInAmount + tokenInFees;
            amountOut = tokenOutAmount + tokenOutFees;
        }

        _transferBothTokens(msg.sender, amountIn, amountOut);

        nearestTick = Ticks.remove(ticks, lower, upper, amount, nearestTick);

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

        TickMath.validatePrice(sqrtPriceLimitX96);

        SwapCache memory cache = SwapCache({
            feeAmount: 0,
            totalFeeAmount: 0,
            protocolFee: 0,
            feeGrowthGlobal: feeGrowthGlobal,
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
                    ticks[cache.nextTickToCross].amountIn += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Execute swap step and cross the tick.
                    output = DyDxMath.getDy(cache.currentLiquidity, nextSqrtPrice, cache.currentPrice, false);
                    cache.currentPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[nearestTick].amountIn += uint128(maxDx);
                    cache.input -= maxDx;
                }
                ticks[cache.nextTickToCross].liquidity -= uint128(output);
     
            } else {
                // sqrtPrice is increasing.
                // Maximum swap amount within the current tick range: Δy = Δ√P · L.
                if (nextSqrtPrice > sqrtPriceLimitX96) { nextSqrtPrice = sqrtPriceLimitX96; }
                uint256 maxDy = DyDxMath.getDy(cache.currentLiquidity, cache.currentPrice, nextSqrtPrice, false);

                if (cache.input <= maxDy) {
                    // We can swap within the current range.
                    // Calculate new sqrtPriceafter swap: ΔP = Δy/L.
                    uint256 newSqrtPrice= cache.currentPrice+
                        FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.currentLiquidity);
                    // Calculate output of swap
                    // - Δx = Δ(1/√P) · L.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentPrice, newSqrtPrice, false);
                    cache.currentPrice= newSqrtPrice;
                    //TODO: should be current tick
                    ticks[nearestTick].amountIn += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Swap & cross the tick.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentPrice, nextSqrtPrice, false);
                    cache.currentPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[nearestTick].amountOut += uint128(maxDy);
                    cache.input -= maxDy;
                }
                ticks[cache.nextTickToCross].liquidity -= uint128(output);
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
                // (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                //     ticks,
                //     cache.nextTickToCross,
                //     secondsGrowthGlobal,
                //     cache.currentLiquidity,
                //     cache.feeGrowthGlobal,
                //     cache.feeGrowthGlobal,
                //     zeroForOne,
                //     tickSpacing
                // );
                if (cache.currentLiquidity == 0) {
                    // We step into a zone that has liquidity - or we reach the end of the linked list.
                    cache.currentPrice= uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
                    // (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                    //     ticks,
                    //     cache.nextTickToCross,
                    //     secondsGrowthGlobal,
                    //     cache.currentLiquidity,
                    //     cache.feeGrowthGlobal,
                    //     cache.feeGrowthGlobal,
                    //     zeroForOne,
                    //     tickSpacing
                    // );
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
            sqrtPrice = uint160(cache.currentPrice);
            int24 newNearestTick = ticks[cache.nextTickToCross].previousTick;
            liquidity = uint128(cache.currentLiquidity);
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
        // start from the current 4nearest tick

        // find the amountIn amountOut needing to be carried over
        // call getAmountsForLiquidity to get amountOut we should carry over
        // if (zeroForOne)
        // then we check amountOut and subtract out the delta
        // any missing amount will be covered using amountIn and averageSqrtPrice0

        // repeat until we capture everything up to the previous TWAP

        // lastly update the TWAP with the most current

        // if TWAP moves down we need to calculate the x difference and remove it
    }

    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        int24 claim,
        int128 amount
    ) internal {
        // if lower < upper
        Position memory position = positions[owner][lower][upper];

        if (amount < 0 && uint128(amount) > position.liquidity) revert NotEnoughPositionLiquidity();

        uint256 priceLower   = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper   = uint256(TickMath.getSqrtRatioAtTick(upper));
        uint256 claimPrice   = uint256(TickMath.getSqrtRatioAtTick(claim));

        if (claimPrice <= position.claimPriceLast) revert InvalidClaimTick();

        // handle claims
        if(ticks[claim].feeGrowthGlobal > position.feeGrowthGlobalLast) {
            // skip claim if lower == claim
            if(claim != lower){
                // calculate what is claimable
                uint128 amountInClaimable; uint128 amountOutClaimable;
                {
                    (uint256 amountInTotal,)     = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, claimPrice, position.liquidity, false);
                    (uint256 amountInClaimed,) = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, position.claimPriceLast, uint128(amount), false);
                    amountInClaimable  = uint128(amountInTotal  - amountInClaimed); //TODO: factor in fees as well
                    uint128 amountInUnfilled = uint128(ticks[claim].percentUnfilled * amountInClaimable / 1e18);
                    amountInClaimable -= amountInUnfilled;
                    amountOutClaimable = uint128(amountInUnfilled * (ticks[claim].unfilledSqrtPrice ** 2));
                }
                // if claim is not upper we verify highest tick with growth
                if (claim != upper){
                    {
                        // next tick should not have any fee growth
                        int24 claimNextTick = ticks[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobal > position.feeGrowthGlobalLast) revert WrongTickClaimedAt();
                    }
                }
                ticks[claim].amountIn  -= uint128(amountInClaimable);
                ticks[claim].amountOut -= uint128(amountOutClaimable);
                //TODO: store in position or transfer to user?
                position.amountIn      += amountInClaimable;
                position.amountOut     += amountOutClaimable;
                position.claimPriceLast = uint160(claimPrice);
                position.feeGrowthGlobalLast = feeGrowthGlobal;
            }
        }

        // update liquidity at claim tick
        if (amount < 0) {
            ( , uint256 amountOutRemoved)     = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, claimPrice, uint128(amount), false);
            // will underflow if too much liquidity withdrawn
            uint128 liquidityAmount = uint128(-amount);
            position.liquidity -= liquidityAmount;
            // liquidity now needs to be removed at claim tick
            ticks[claim].liquidity += liquidityAmount;
            // liquidity at upper tick need not be removed anymore
            ticks[upper].liquidity -= liquidityAmount;
            _transferOut(owner, tokenOut, amountOutRemoved);
        }

        if (amount > 0) {
            //TODO: i'm not sure how to handle double mints just yet
            // it would probably have to be two different positions
            // since we use claimPriceLast
            // only other solution is to take all their current liquidity
            // and then respread it over whatever range they select
            // if they haven't claimed at all it's fine
            // can we recalculate claimPriceLast?
            if(position.liquidity > 0) revert NotImplementedYet();
            position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }
    }
}
