// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface IUnsafeMath {
    function divRoundingUp(
        uint256 x,
        uint256 y
    ) external pure returns (uint256 z);
}