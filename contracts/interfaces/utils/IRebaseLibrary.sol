// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

struct Rebase {
    uint128 elastic;
    uint128 base;
}

interface IRebaseLibrary {
    function toBase(
        Rebase memory total,
        uint256 elastic
    ) external pure returns (uint256 base);

    function toElastic(
        Rebase memory total,
        uint256 base
    ) external pure returns (uint256 elastic);
}

