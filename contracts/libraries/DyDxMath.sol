// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./FullPrecisionMath.sol";
import "./UnsafeMath.sol";
import "./SafeCast.sol";

/// @notice Math library that facilitates ranged liquidity calculations.
library DyDxMath {
    function getDy(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) internal pure returns (uint256 dy) {
        unchecked {
            if (roundUp) {
                dy = FullPrecisionMath.mulDivRoundingUp(liquidity, priceUpper - priceLower, 0x1000000000000000000000000);
            } else {
                dy = FullPrecisionMath.mulDiv(liquidity, priceUpper - priceLower, 0x1000000000000000000000000);
            }
        }
    }

    function getDx(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) internal pure returns (uint256 dx) {
        unchecked {
            if (roundUp) {
                dx = UnsafeMath.divRoundingUp(FullPrecisionMath.mulDivRoundingUp(liquidity << 96, priceUpper - priceLower, priceUpper), priceLower);
            } else {
                dx = FullPrecisionMath.mulDiv(liquidity << 96, priceUpper - priceLower, priceUpper) / priceLower;
            }
        }
    }

    function getLiquidityForAmounts(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 dy,
        uint256 dx
    ) internal pure returns (uint256 liquidity) {
        unchecked {
            if (priceUpper <= currentPrice) {
                liquidity = FullPrecisionMath.mulDiv(dy, 0x1000000000000000000000000, priceUpper - priceLower);
            } else if (currentPrice <= priceLower) {
                liquidity = FullPrecisionMath.mulDiv(
                    dx,
                    FullPrecisionMath.mulDiv(priceLower, priceUpper, 0x1000000000000000000000000),
                    priceUpper - priceLower
                );
            } else {
                uint256 liquidity1 = FullPrecisionMath.mulDiv(dy, 0x1000000000000000000000000, currentPrice - priceLower);
                liquidity = liquidity1;
            }
        }
    }

    function getAmountsForLiquidity(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 liquidityAmount,
        bool roundUp
    ) internal pure returns (uint128 token0amount, uint128 token1amount) {
        if (priceUpper <= currentPrice) {
            // Only supply `token1` (`token1` is Y).
            token1amount = SafeCast.toUint128(DyDxMath.getDy(liquidityAmount, priceLower, priceUpper, roundUp));
        } else if (currentPrice <= priceLower) {
            // Only supply `token0` (`token0` is X).
            token0amount = SafeCast.toUint128(DyDxMath.getDx(liquidityAmount, priceLower, priceUpper, roundUp));
        } else {
            // Supply both tokens.
            token0amount = SafeCast.toUint128(DyDxMath.getDx(liquidityAmount, currentPrice, priceUpper, roundUp));
            token1amount = SafeCast.toUint128(DyDxMath.getDy(liquidityAmount, priceLower, currentPrice, roundUp));
        }
    }
}
