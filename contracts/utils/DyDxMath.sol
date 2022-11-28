// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./SafeCast.sol";
import "./UnsafeMath.sol";
import "./FullPrecisionMath.sol";
import "../interfaces/utils/IDyDxMath.sol";
import "hardhat/console.sol";

/// @notice Math library that facilitates ranged liquidity calculations.
abstract contract DyDxMath is
    IDyDxMath,
    FullPrecisionMath,
    SafeCast,
    UnsafeMath
{
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
                dy = _mulDivRoundingUp(liquidity, priceUpper - priceLower, 0x1000000000000000000000000);
            } else {
                dy = _mulDiv(liquidity, priceUpper - priceLower, 0x1000000000000000000000000);
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
                dx = divRoundingUp(_mulDivRoundingUp(liquidity << 96, priceUpper - priceLower, priceUpper), priceLower);
            } else {
                dx = _mulDiv(liquidity << 96, priceUpper - priceLower, priceUpper) / priceLower;
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
            if (priceUpper <= currentPrice) {
                liquidity = _mulDiv(dy, 0x1000000000000000000000000, priceUpper - priceLower);
            } else if (currentPrice <= priceLower) {
                liquidity = _mulDiv(
                    dx,
                    _mulDiv(priceLower, priceUpper, 0x1000000000000000000000000),
                    priceUpper - priceLower
                );
            } else {
                uint256 liquidity1 = _mulDiv(dy, 0x1000000000000000000000000, currentPrice - priceLower);
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
    ) external view returns (uint128 token0amount, uint128 token1amount) {
        if (priceUpper <= currentPrice) {
            // Only supply `token1` (`token1` is Y).
            token1amount = _toUint128(_getDy(liquidityAmount, priceLower, priceUpper, roundUp));
        } else if (currentPrice <= priceLower) {
            // Only supply `token0` (`token0` is X).
            token0amount = _toUint128(_getDx(liquidityAmount, priceLower, priceUpper, roundUp));
        } else {
            // Supply both tokens.
            token0amount = _toUint128(_getDx(liquidityAmount, currentPrice, priceUpper, roundUp));
            token1amount = _toUint128(_getDy(liquidityAmount, priceLower, currentPrice, roundUp));
        }
        console.log("tokenIn amount:        ", token0amount);
        console.log("tokenOut amount:       ", token1amount);
    }
}
