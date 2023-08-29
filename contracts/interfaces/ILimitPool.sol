// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../interfaces/structs/PoolsharkStructs.sol';

interface ILimitPool is PoolsharkStructs {
    function immutables() external view returns (LimitImmutables memory);
}
