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

/// @notice Trident Concentrated liquidity pool implementation.
/// @dev SafeTransfers contains PoolsharkHedgePoolErrors
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkHedgePoolView,
    SafeTransfers,
    TwapOracle
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

    using Ticks for mapping(int24 => Tick);

    constructor(bytes memory _poolParams) {
        (
            address _factory,
            address _inputPool,
            address _token0, 
            address _token1, 
            uint24  _swapFee, 
            uint24  _tickSpacing
        ) = abi.decode(
            _poolParams,
            (
                address, 
                address, 
                address,
                address,
                uint24,
                uint24
            )
        );

        // check for invalid params
        if (_token0 == address(0) || _token0 == address(this)) revert InvalidToken();
        if (_token1 == address(0) || _token1 == address(this)) revert InvalidToken();
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = _factory;
        inputPool   = _inputPool;
        token0      = _token0;
        token1      = _token1;
        swapFee     = _swapFee;
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(_factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);
        // ticks[TickMath.MIN_TICK] = Tick(TickMath.MIN_TICK, TickMath.MAX_TICK, uint128(0), 0, 0, 0);
        // ticks[TickMath.MAX_TICK] = Tick(TickMath.MIN_TICK, TickMath.MAX_TICK, uint128(0), 0, 0, 0);
        
        // set default initial values
        nearestTick0 = calculateAverageTick(IConcentratedPool(inputPool));
        nearestTick1 = calculateAverageTick(IConcentratedPool(inputPool));
        sqrtPrice0 = TickMath.getSqrtRatioAtTick(nearestTick0);
        sqrtPrice1 = TickMath.getSqrtRatioAtTick(nearestTick1);
        unlocked = 1;
        lastObservation = uint32(block.timestamp);
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        _ensureTickSpacing(mintParams.lower, mintParams.upper);

        if (mintParams.amount0Desired == 0 && mintParams.amount1Desired == 0) { revert InvalidPosition(); }
        if (mintParams.lower >= mintParams.upper) { revert InvalidPosition(); }

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        uint256 currentSqrtPrice;
        uint256 priceEntry;

        if(mintParams.zeroForOne){
            // position lower and upper should be above current price
            currentSqrtPrice = uint256(sqrtPrice0);
            if (priceLower <= currentSqrtPrice) { revert InvalidPosition(); }
            if (mintParams.amount0Desired == 0) { revert InvalidPosition(); }
            priceEntry = priceUpper;

            liquidityMinted = DyDxMath.getLiquidityForAmounts(
                priceLower,
                priceUpper,
                currentSqrtPrice,
                0,
                uint256(mintParams.amount0Desired)
            );

            unchecked {
                // liquidity should always be out of range initially
                //if (priceLower <= currentSqrtPrice && currentSqrtPrice < priceUpper) liquidity += uint128(liquidityMinted);
            }

            Ticks.insert(
                ticks,
                feeGrowthGlobal0,
                feeGrowthGlobal1,
                secondsGrowthGlobal,
                mintParams.lowerOld,
                mintParams.lower,
                mintParams.upperOld,
                mintParams.upper,
                uint128(liquidityMinted),
                nearestTick0,
                uint160(currentSqrtPrice)
            );
            // if tick is in range of the current TWAP, update nearestTick0/1
        } else {
            // position upper should be lower than current price
            currentSqrtPrice = uint256(sqrtPrice1);
            if (priceUpper >= currentSqrtPrice) { revert InvalidPosition(); }
            if (mintParams.amount1Desired == 0) { revert InvalidPosition(); }
            priceEntry = priceLower;
            unchecked {
                liquidityMinted = DyDxMath.getLiquidityForAmounts(
                    priceLower,
                    priceUpper,
                    priceUpper,
                    uint256(mintParams.amount1Desired),
                    0
                );
            }
        }

        // _updateSecondsPerLiquidity(uint256(liquidity));

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert Overflow();
        

        //TODO: handle with new Tick struct


        (uint128 amount0Actual, uint128 amount1Actual) = DyDxMath.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            priceEntry,
            liquidityMinted,
            true
        );

        (uint256 amount0, uint256 amount1Fees) = _updatePosition(
            msg.sender,
            mintParams.lower,
            mintParams.upper,
            mintParams.zeroForOne,
            int128(uint128(liquidityMinted)),
            false,
            0
        );

        IPositionManager(msg.sender).mintCallback(token0, token1, amount0Actual, amount1Actual, mintParams.native);

        emit Mint(msg.sender, amount0Actual, amount1Actual);
    }

    function burn(
        int24 lower,
        int24 upper,
        uint128 amount
    )
        public
        lock
        returns (
            uint256 token0Amount,
            uint256 token1Amount,
            uint256 token0Fees,
            uint256 token1Fees
        )
    {
        uint160 priceLower = TickMath.getSqrtRatioAtTick(lower);
        uint160 priceUpper = TickMath.getSqrtRatioAtTick(upper);
        uint160 currentSqrtPrice= sqrtPrice0;

        _updateSecondsPerLiquidity(uint256(liquidity0));

        unchecked {
            if (priceLower <= currentSqrtPrice&& currentSqrtPrice< priceUpper) liquidity0 -= amount;
        }

        (token0Amount, token1Amount) = DyDxMath.getAmountsForLiquidity(
            uint256(priceLower),
            uint256(priceUpper),
            uint256(currentSqrtPrice),
            uint256(amount),
            false
        );

        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert Overflow();

        // (token0Fees, token1Fees) = _updatePosition(msg.sender, lower, upper, -int128(amount));

        uint256 amount0;
        uint256 amount1;

        unchecked {
            amount0 = token0Amount + token0Fees;
            amount1 = token1Amount + token1Fees;
        }

        _transferBothTokens(msg.sender, amount0, amount1);

        nearestTick0 = Ticks.remove(ticks, lower, upper, amount, nearestTick0);

        emit Burn(msg.sender, amount0, amount1);
    }

    // function collect(int24 lower, int24 upper) public lock returns (uint256 amount0fees, uint256 amount1fees) {
    //     (amount0fees, amount1fees) = _updatePosition(
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

    //     _transferBothTokens(msg.sender, amount0fees, amount1fees);

    //     emit Collect(msg.sender, amount0fees, amount1fees);
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
            feeGrowthGlobalA: zeroForOne ? feeGrowthGlobal1 : feeGrowthGlobal0,
            feeGrowthGlobalB: zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            currentSqrtPrice: zeroForOne ? uint256(sqrtPrice1) : uint256(sqrtPrice0),
            currentLiquidity: zeroForOne ? uint256(liquidity1) : uint256(liquidity0),
            input: amountIn,
            nextTickToCross: zeroForOne ? nearestTick0 : nearestTick1
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
                uint256 maxDx = DyDxMath.getDx(cache.currentLiquidity, nextSqrtPrice, cache.currentSqrtPrice, false);

                if (cache.input <= maxDx) {
                    // We can swap within the current range.
                    uint256 liquidityPadded = cache.currentLiquidity << 96;
                    // Calculate new sqrtPriceafter swap: √𝑃[new] =  L · √𝑃 / (L + Δx · √𝑃)
                    // This is derived from Δ(1/√𝑃) = Δx/L
                    // where Δ(1/√𝑃) is 1/√𝑃[old] - 1/√𝑃[new] and we solve for √𝑃[new].
                    // In case of an overflow we can use: √𝑃[new] = L / (L / √𝑃 + Δx).
                    // This is derived by dividing the original fraction by √𝑃 on both sides.
                    uint256 newSqrtPrice = uint256(
                        FullPrecisionMath.mulDivRoundingUp(liquidityPadded, cache.currentSqrtPrice, liquidityPadded + cache.currentSqrtPrice * cache.input)
                    );

                    if (!(nextSqrtPrice <= newSqrtPrice && newSqrtPrice < cache.currentSqrtPrice)) {
                        // Overflow. We use a modified version of the formula.
                        newSqrtPrice = uint160(UnsafeMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.currentSqrtPrice+ cache.input));
                    }
                    // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                    output = DyDxMath.getDy(cache.currentLiquidity, newSqrtPrice, cache.currentSqrtPrice, false);
                    cache.currentSqrtPrice= newSqrtPrice;
                    //TODO: should be current tick
                    ticks[cache.nextTickToCross].amount0 += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Execute swap step and cross the tick.
                    output = DyDxMath.getDy(cache.currentLiquidity, nextSqrtPrice, cache.currentSqrtPrice, false);
                    cache.currentSqrtPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[nearestTick0].amount0 += uint128(maxDx);
                    cache.input -= maxDx;
                }
                ticks[cache.nextTickToCross].liquidity1 -= uint128(output);
     
            } else {
                // sqrtPrice is increasing.
                // Maximum swap amount within the current tick range: Δy = Δ√P · L.
                if (nextSqrtPrice > sqrtPriceLimitX96) { nextSqrtPrice = sqrtPriceLimitX96; }
                uint256 maxDy = DyDxMath.getDy(cache.currentLiquidity, cache.currentSqrtPrice, nextSqrtPrice, false);

                if (cache.input <= maxDy) {
                    // We can swap within the current range.
                    // Calculate new sqrtPriceafter swap: ΔP = Δy/L.
                    uint256 newSqrtPrice= cache.currentSqrtPrice+
                        FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.currentLiquidity);
                    // Calculate output of swap
                    // - Δx = Δ(1/√P) · L.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentSqrtPrice, newSqrtPrice, false);
                    cache.currentSqrtPrice= newSqrtPrice;
                    //TODO: should be current tick
                    ticks[nearestTick0].amount0 += uint128(cache.input);
                    cache.input = 0;
                } else {
                    // Swap & cross the tick.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentSqrtPrice, nextSqrtPrice, false);
                    cache.currentSqrtPrice= nextSqrtPrice;
                    if (nextSqrtPrice == nextTickSqrtPrice) { cross = true; }
                    //TODO: should be current tick
                    ticks[nearestTick0].amount1 += uint128(maxDy);
                    cache.input -= maxDy;
                }
                ticks[cache.nextTickToCross].liquidity0 -= uint128(output);
            }

            // cache.feeGrowthGlobalA is the feeGrowthGlobal counter for the output token.
            // It increases each swap step.
            (cache.totalFeeAmount, amountOut, cache.protocolFee, cache.feeGrowthGlobalA) = SwapLib.handleFees(
                output,
                swapFee,
                cache.currentLiquidity,
                cache.totalFeeAmount,
                amountOut,
                cache.protocolFee,
                cache.feeGrowthGlobalA
            );
            if (cross) {
                // (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                //     ticks,
                //     cache.nextTickToCross,
                //     secondsGrowthGlobal,
                //     cache.currentLiquidity,
                //     cache.feeGrowthGlobalA,
                //     cache.feeGrowthGlobalB,
                //     zeroForOne,
                //     tickSpacing
                // );
                if (cache.currentLiquidity == 0) {
                    // We step into a zone that has liquidity - or we reach the end of the linked list.
                    cache.currentSqrtPrice= uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
                    // (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                    //     ticks,
                    //     cache.nextTickToCross,
                    //     secondsGrowthGlobal,
                    //     cache.currentLiquidity,
                    //     cache.feeGrowthGlobalA,
                    //     cache.feeGrowthGlobalB,
                    //     zeroForOne,
                    //     tickSpacing
                    // );
                }
            } else {
                break;
            }
        }

        if (zeroForOne){
            sqrtPrice1 = uint160(cache.currentSqrtPrice);
            int24 newNearestTick = cache.nextTickToCross;
            if(nearestTick1 != newNearestTick){
                nearestTick1 = newNearestTick;
                liquidity1 = uint128(cache.currentLiquidity);
            }
        } else {
            sqrtPrice0 = uint160(cache.currentSqrtPrice);
            int24 newNearestTick = ticks[cache.nextTickToCross].previousTick;
            liquidity1 = uint128(cache.currentLiquidity);
        }

        _updateFees(zeroForOne, cache.feeGrowthGlobalA, uint128(cache.protocolFee));

        if (zeroForOne) {
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token0, token1, amountIn, amountOut);
        } else {
            _transferOut(recipient, token0, amountOut);
            emit Swap(recipient, token1, token0, amountIn, amountOut);
        }
    }

    /// @dev Collects fees for Poolshark protocol.
    function collectProtocolFee() public lock returns (uint128 amount0, uint128 amount1) {
        if (token0ProtocolFee > 1) {
            amount0 = token0ProtocolFee - 1;
            token0ProtocolFee = 1;
            _transferOut(feeTo, token0, amount0);
        }
        if (token1ProtocolFee > 1) {
            amount1 = token1ProtocolFee - 1;
            token1ProtocolFee = 1;
            _transferOut(feeTo, token1, amount1);
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
        uint256 currentPrice = uint256(sqrtPrice0);
        int24 nextTickToCross = tokenOut == token1 ? nearestTick0 : ticks[nearestTick0].nextTick;
        int24 nextTick;

        finalAmountIn = 0;
        while (amountOutWithoutFee != 0) {
            uint256 nextTickPrice = uint256(TickMath.getSqrtRatioAtTick(nextTickToCross));
            if (tokenOut == token1) {
                uint256 currentLiquidity = uint256(liquidity1);
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
                            currentLiquidity -= ticks[nextTickToCross].liquidity0;
                        } else {
                            currentLiquidity += ticks[nextTickToCross].liquidity0;
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
                uint256 currentLiquidity = uint256(liquidity0);
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
                            currentLiquidity += ticks[nextTickToCross].liquidity0;
                        } else {
                            currentLiquidity -= ticks[nextTickToCross].liquidity0;
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
        _transferOut(to, token0, shares0);
        _transferOut(to, token1, shares1);
    }

    function _updateFees(
        bool zeroForOne,
        uint256 feeGrowthGlobal,
        uint128 protocolFee
    ) internal {
        if (zeroForOne) {
            feeGrowthGlobal1 = feeGrowthGlobal;
            token1ProtocolFee += protocolFee;
        } else {
            feeGrowthGlobal0 = feeGrowthGlobal;
            token0ProtocolFee += protocolFee;
        }
    }

    function _accumulateLastBlock() internal {
        // start from the current nearest tick

        // find the amount0 amount1 needing to be carried over
        // call getAmountsForLiquidity to get amount1 we should carry over
        // if (zeroForOne)
        // then we check amount1 and subtract out the delta
        // any missing amount will be covered using amount0 and averageSqrtPrice0

        // repeat until we capture everything up to the previous TWAP

        // lastly update the TWAP with the most current
    }

    // to claim the current token amounts..
    // we need to find the highest tick that
    // has had feeGrowthGlobal > that of the position
    // if there has been no fee growth we need to go down
    // if there is fee growth we need to go up until there is none
    // or we reach end of range
    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        bool zeroForOne,
        int128 amount,
        bool claiming,
        int24 claim
    ) internal returns (uint256 amount0, uint256 amount1) {
        // if lower < upper
        Position storage position = positions[owner][lower][upper][zeroForOne];

        // if claim 
        // check feeGrowthLast and compare to position
        bool feeGrowthSinceLastUpdate;
        if(zeroForOne){
            feeGrowthSinceLastUpdate = ticks[claim].feeGrowthGlobal1 > position.feeGrowthGlobalLast;

            if(feeGrowthSinceLastUpdate) {
                if(claim == upper){
                    // we can process the claim
                    //uint256 amount0 = DyDxMath.getAmountsForLiquidity(priceLower, priceUpper, currentPrice, liquidityAmount, roundUp);
                } else {
                    // check to see if tick above has fee growth
                    // if so revert()
                }
            } else {
                // revert()
            }

            position.feeGrowthGlobalLast = feeGrowthGlobal1;
        } else {
            feeGrowthSinceLastUpdate = ticks[claim].feeGrowthGlobal0 > position.feeGrowthGlobalLast;

            if(feeGrowthSinceLastUpdate) {
                if(claim == lower){
                    // we can process the claim
                } else {
                    // we keep going to a higher tick until we find
                    // one without fee growth
                }
            } else {
                // we keep going to a lower tick until we find
                // one with fee growth
            }

            position.feeGrowthGlobalLast = feeGrowthGlobal0;
        }

        // assume we've set the proper claim tick

        // calculate max claimable at current tick

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(upper));
        uint256 priceClaim = uint256(TickMath.getSqrtRatioAtTick(claim));

        (uint128 amount0Actual, uint128 amount1Actual) = DyDxMath.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            priceClaim,
            position.liquidity,
            false
        );

        // claim the max allowable

        // subtract from amount0 and amount1

        // update highestTickClaimed and amountClaimed on position

        //TODO: depends on direction which side acquired fees
        // amount0Fees = FullPrecisionMath.mulDiv(
        //     swapFee,
        //     position.liquidity,
        //     0x100000000000000000000000000000000
        // );

        // amount1Fees = FullPrecisionMath.mulDiv(
        //     rangeFeeGrowth1 - position.feeGrowthInside1Last,
        //     position.liquidity,
        //     0x100000000000000000000000000000000
        // );

        if (amount < 0) {
            position.liquidity -= uint128(-amount);
        }

        if (amount > 0) {
            position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }
    }
}
