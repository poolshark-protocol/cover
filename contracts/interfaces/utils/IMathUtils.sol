// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

interface IMathUtils {
    function within1(
        uint256 a,
        uint256 b
    ) external pure returns (bool);

    function sqrt(
        uint256 x
    ) external pure returns (uint256 z);
}

