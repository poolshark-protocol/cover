// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import '../../../interfaces/modules/curves/ICurveMath.sol';
import '../../../libraries/math/FullPrecisionMath.sol';

/// @notice Math library that facilitates ranged liquidity calculations.
abstract contract DyDxMath
{
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    error PriceOutsideBounds();

    function getDy(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) external pure returns (uint256 dy) {
        return _getDy(liquidity, priceLower, priceUpper, roundUp);
    }

    function getDx(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) external pure returns (uint256 dx) {
        return _getDx(liquidity, priceLower, priceUpper, roundUp);
    }

    function _getDy(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) internal pure returns (uint256 dy) {
        unchecked {
            if (roundUp) {
                dy = FullPrecisionMath.mulDivRoundingUp(liquidity, priceUpper - priceLower, Q96);
            } else {
                dy = FullPrecisionMath.mulDiv(liquidity, priceUpper - priceLower, Q96);
            }
        }
    }

    function _getDx(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) internal pure returns (uint256 dx) {
        unchecked {
            if (roundUp) {
                dx = FullPrecisionMath.divRoundingUp(FullPrecisionMath.mulDivRoundingUp(liquidity << 96, priceUpper - priceLower, priceUpper), priceLower);
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
    ) external pure returns (uint256 liquidity) {
        unchecked {
            if (priceUpper == currentPrice) {
                liquidity = FullPrecisionMath.mulDiv(dy, Q96, priceUpper - priceLower);
            } else if (currentPrice == priceLower) {
                liquidity = FullPrecisionMath.mulDiv(
                    dx,
                    FullPrecisionMath.mulDiv(priceLower, priceUpper, Q96),
                    priceUpper - priceLower
                );
            } else {
                /// @dev - price should either be priceUpper or priceLower
                revert PriceOutsideBounds();
            }  
        }
    }

    function getAmountsForLiquidity(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 liquidityAmount,
        bool roundUp
    ) external pure returns (uint128 token0amount, uint128 token1amount) {
        if (priceUpper <= currentPrice) {
            token1amount = uint128(_getDy(liquidityAmount, priceLower, priceUpper, roundUp));
        } else if (currentPrice <= priceLower) {
            token0amount = uint128(_getDx(liquidityAmount, priceLower, priceUpper, roundUp));
        } else {
            token0amount = uint128(_getDx(liquidityAmount, currentPrice, priceUpper, roundUp));
            token1amount = uint128(_getDy(liquidityAmount, priceLower, currentPrice, roundUp));
        }
    }
}
