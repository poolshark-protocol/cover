// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.13;

interface IRangePoolFactory {
    function getRangePool(
        address fromToken,
        address destToken,
        uint16 fee
    ) external view returns (address);
}
