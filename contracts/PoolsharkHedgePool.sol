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

/// @notice Trident Concentrated liquidity pool implementation.
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkHedgePoolView,
    SafeTransfers
{
    modifier lock() {
        if (unlocked == 2) revert Locked();
        unlocked = 2;
        _;
        unlocked = 1;
    }

    using Ticks for mapping(int24 => Tick);

    constructor(bytes memory _deployParams) {
        (
            address _poolFactory,
            address _token0, 
            address _token1, 
            uint24  _swapFee, 
            uint24  _tickSpacing
        ) = abi.decode(
            _deployParams,
            (
                address, 
                address, 
                address, 
                uint24,
                uint24
            )
        );

        if (_token0 == address(0) || _token0 == address(this)) revert InvalidToken();
        if (_token1 == address(0) || _token1 == address(this)) revert InvalidToken();
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        token0 = _token0;
        token1 = _token1;
        swapFee = _swapFee;
        tickSpacing = _tickSpacing;
        poolFactory = _poolFactory;
        feeTo = IPoolsharkHedgePoolFactory(_poolFactory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);
        ticks[TickMath.MIN_TICK] = Tick(TickMath.MIN_TICK, TickMath.MAX_TICK, uint128(0), 0, 0, 0);
        ticks[TickMath.MAX_TICK] = Tick(TickMath.MIN_TICK, TickMath.MAX_TICK, uint128(0), 0, 0, 0);
        nearestTick = TickMath.MIN_TICK;
        unlocked = 1;
        lastObservation = uint32(block.timestamp);
    }

    uint24 internal immutable tickSpacing;
    uint24 internal immutable swapFee; /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
    uint128 internal immutable MAX_TICK_LIQUIDITY;

    address internal immutable poolFactory;
    address internal immutable token0;
    address internal immutable token1;

    /// @dev Called only once from the factory.
    /// @dev sqrtPriceis not a constructor parameter to allow for predictable address calculation.
    function setPrice(uint160 _sqrtPrice) external {
        if (sqrtPrice== 0) {
            TickMath.validatePrice(_sqrtPrice);
            sqrtPrice= _sqrtPrice;
        }
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(MintParams memory mintParams) public lock returns (uint256 liquidityMinted) {
        _ensureTickSpacing(mintParams.lower, mintParams.upper);

        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        uint256 currentSqrtPrice = uint256(sqrtPrice);

        liquidityMinted = DyDxMath.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            currentSqrtPrice,
            uint256(mintParams.amount1Desired),
            uint256(mintParams.amount0Desired)
        );

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert Overflow();

        _updateSecondsPerLiquidity(uint256(liquidity));

        unchecked {
            (uint256 amount0Fees, uint256 amount1Fees) = _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                int128(uint128(liquidityMinted))
            );

            if (priceLower <= currentSqrtPrice && currentSqrtPrice< priceUpper) liquidity += uint128(liquidityMinted);
        }

        nearestTick = Ticks.insert(
            ticks,
            feeGrowthGlobal0,
            feeGrowthGlobal1,
            secondsGrowthGlobal,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            nearestTick,
            uint160(currentSqrtPrice)
        );

        (uint128 amount0Actual, uint128 amount1Actual) = DyDxMath.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            currentSqrtPrice,
            liquidityMinted,
            true
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
        uint160 currentSqrtPrice= sqrtPrice;

        _updateSecondsPerLiquidity(uint256(liquidity));

        unchecked {
            if (priceLower <= currentSqrtPrice&& currentSqrtPrice< priceUpper) liquidity -= amount;
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

        (token0Fees, token1Fees) = _updatePosition(msg.sender, lower, upper, -int128(amount));

        uint256 amount0;
        uint256 amount1;

        unchecked {
            amount0 = token0Amount + token0Fees;
            amount1 = token1Amount + token1Fees;
        }

        _transferBothTokens(msg.sender, amount0, amount1);

        nearestTick = Ticks.remove(ticks, lower, upper, amount, nearestTick);

        emit Burn(msg.sender, amount0, amount1);
    }

    function collect(int24 lower, int24 upper) public lock returns (uint256 amount0fees, uint256 amount1fees) {
        (amount0fees, amount1fees) = _updatePosition(msg.sender, lower, upper, 0);

        _transferBothTokens(msg.sender, amount0fees, amount1fees);

        emit Collect(msg.sender, amount0fees, amount1fees);
    }

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
        uint256 amountIn
        // uint160 sqrtPriceLimitX96,
        // bytes calldata data
    ) external override lock returns (uint256 amountOut) {

        SwapCache memory cache = SwapCache({
            feeAmount: 0,
            totalFeeAmount: 0,
            protocolFee: 0,
            feeGrowthGlobalA: zeroForOne ? feeGrowthGlobal1 : feeGrowthGlobal0,
            feeGrowthGlobalB: zeroForOne ? feeGrowthGlobal0 : feeGrowthGlobal1,
            currentSqrtPrice: uint256(sqrtPrice),
            currentLiquidity: uint256(liquidity),
            input: amountIn,
            nextTickToCross: zeroForOne ? nearestTick : ticks[nearestTick].nextTick
        });

        _updateSecondsPerLiquidity(cache.currentLiquidity);

        while (cache.input != 0) {
            uint256 nextTickSqrtPrice= uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
            uint256 output = 0;
            bool cross = false;

            if (zeroForOne) {
                // Trading token 0 (x) for token 1 (y).
                // sqrtPriceis decreasing.
                // Maximum input amount within current tick range: Δx = Δ(1/√𝑃) · L.
                uint256 maxDx = DyDxMath.getDx(cache.currentLiquidity, nextTickSqrtPrice, cache.currentSqrtPrice, false);

                if (cache.input <= maxDx) {
                    // We can swap within the current range.
                    uint256 liquidityPadded = cache.currentLiquidity << 96;
                    // Calculate new sqrtPriceafter swap: √𝑃[new] =  L · √𝑃 / (L + Δx · √𝑃)
                    // This is derived from Δ(1/√𝑃) = Δx/L
                    // where Δ(1/√𝑃) is 1/√𝑃[old] - 1/√𝑃[new] and we solve for √𝑃[new].
                    // In case of an overflow we can use: √𝑃[new] = L / (L / √𝑃 + Δx).
                    // This is derived by dividing the original fraction by √𝑃 on both sides.
                    uint256 newSqrtPrice= uint256(
                        FullPrecisionMath.mulDivRoundingUp(liquidityPadded, cache.currentSqrtPrice, liquidityPadded + cache.currentSqrtPrice* cache.input)
                    );

                    if (!(nextTickSqrtPrice<= newSqrtPrice&& newSqrtPrice< cache.currentSqrtPrice)) {
                        // Overflow. We use a modified version of the formula.
                        newSqrtPrice= uint160(UnsafeMath.divRoundingUp(liquidityPadded, liquidityPadded / cache.currentSqrtPrice+ cache.input));
                    }
                    // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                    output = DyDxMath.getDy(cache.currentLiquidity, newSqrtPrice, cache.currentSqrtPrice, false);
                    cache.currentSqrtPrice= newSqrtPrice;
                    cache.input = 0;
                } else {
                    // Execute swap step and cross the tick.
                    output = DyDxMath.getDy(cache.currentLiquidity, nextTickSqrtPrice, cache.currentSqrtPrice, false);
                    cache.currentSqrtPrice= nextTickSqrtPrice;
                    cross = true;
                    cache.input -= maxDx;
                }
            } else {
                // sqrtPriceis increasing.
                // Maximum swap amount within the current tick range: Δy = Δ√P · L.
                uint256 maxDy = DyDxMath.getDy(cache.currentLiquidity, cache.currentSqrtPrice, nextTickSqrtPrice, false);

                if (cache.input <= maxDy) {
                    // We can swap within the current range.
                    // Calculate new sqrtPriceafter swap: ΔP = Δy/L.
                    uint256 newSqrtPrice= cache.currentSqrtPrice+
                        FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.currentLiquidity);
                    // Calculate output of swap
                    // - Δx = Δ(1/√P) · L.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentSqrtPrice, newSqrtPrice, false);
                    cache.currentSqrtPrice= newSqrtPrice;
                    cache.input = 0;
                } else {
                    // Swap & cross the tick.
                    output = DyDxMath.getDx(cache.currentLiquidity, cache.currentSqrtPrice, nextTickSqrtPrice, false);
                    cache.currentSqrtPrice= nextTickSqrtPrice;
                    cross = true;
                    cache.input -= maxDy;
                }
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
                (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                    ticks,
                    cache.nextTickToCross,
                    secondsGrowthGlobal,
                    cache.currentLiquidity,
                    cache.feeGrowthGlobalA,
                    cache.feeGrowthGlobalB,
                    zeroForOne,
                    tickSpacing
                );
                if (cache.currentLiquidity == 0) {
                    // We step into a zone that has liquidity - or we reach the end of the linked list.
                    cache.currentSqrtPrice= uint256(TickMath.getSqrtRatioAtTick(cache.nextTickToCross));
                    (cache.currentLiquidity, cache.nextTickToCross) = Ticks.cross(
                        ticks,
                        cache.nextTickToCross,
                        secondsGrowthGlobal,
                        cache.currentLiquidity,
                        cache.feeGrowthGlobalA,
                        cache.feeGrowthGlobalB,
                        zeroForOne,
                        tickSpacing
                    );
                }
            }
        }

        sqrtPrice= uint160(cache.currentSqrtPrice);

        int24 newNearestTick = zeroForOne ? cache.nextTickToCross : ticks[cache.nextTickToCross].previousTick;

        if (nearestTick != newNearestTick) {
            nearestTick = newNearestTick;
            liquidity = uint128(cache.currentLiquidity);
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
        uint256 currentPrice = uint256(sqrtPrice);
        uint256 currentLiquidity = uint256(liquidity);
        int24 nextTickToCross = tokenOut == token1 ? nearestTick : ticks[nearestTick].nextTick;
        int24 nextTick;

        finalAmountIn = 0;
        while (amountOutWithoutFee != 0) {
            uint256 nextTickPrice = uint256(TickMath.getSqrtRatioAtTick(nextTickToCross));
            if (tokenOut == token1) {
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
            require(nextTickToCross != nextTick, "CL:Insufficient output liquidity");
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

    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        int128 amount
    ) internal returns (uint256 amount0Fees, uint256 amount1Fees) {
        Position storage position = positions[owner][lower][upper];

        (uint256 rangeFeeGrowth0, uint256 rangeFeeGrowth1) = rangeFeeGrowth(lower, upper);

        amount0Fees = FullPrecisionMath.mulDiv(
            rangeFeeGrowth0 - position.feeGrowthInside0Last,
            position.liquidity,
            0x100000000000000000000000000000000
        );

        amount1Fees = FullPrecisionMath.mulDiv(
            rangeFeeGrowth1 - position.feeGrowthInside1Last,
            position.liquidity,
            0x100000000000000000000000000000000
        );

        if (amount < 0) {
            position.liquidity -= uint128(-amount);
        }

        if (amount > 0) {
            position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }

        position.feeGrowthInside0Last = rangeFeeGrowth0;
        position.feeGrowthInside1Last = rangeFeeGrowth1;
    }

}
