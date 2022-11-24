// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface ISafeCast {
    function toUint160(
        uint256 y
    ) external pure returns (uint160 z);

    function toUint128(
        uint256 y
    ) external pure returns (uint128 z);
}

