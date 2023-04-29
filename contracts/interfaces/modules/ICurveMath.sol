// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface ICurveMath {
    function getDy(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) external pure returns (
        uint256 dy
    );

    function getDx(
        uint256 liquidity,
        uint256 priceLower,
        uint256 priceUpper,
        bool roundUp
    ) external pure returns (
        uint256 dx
    );

    function getLiquidityForAmounts(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 currentPrice,
        uint256 dy,
        uint256 dx
    ) external pure returns (
        uint256 liquidity
    );

    function getAmountsForLiquidity(
        uint256 priceLower,
        uint256 priceUpper,
        uint256 price,
        uint256 liquidity,
        bool roundUp
    ) external pure returns (
        uint128 token0amount,
        uint128 token1amount
    );
}
