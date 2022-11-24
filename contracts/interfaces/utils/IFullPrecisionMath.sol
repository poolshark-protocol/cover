// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IFullPrecisionMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256 result);

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256 result);
}
