// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/cover/ICoverPoolFactory.sol';
import '../../utils/CoverPoolErrors.sol';

abstract contract CoverPoolStorage is CoverPoolStructs, CoverPoolErrors {
    GlobalState public globalState;
    PoolState public pool0; /// @dev pool with token0 liquidity
    PoolState public pool1; /// @dev pool with token1 liquidity
    TickMap public tickMap;
    mapping(int24 => Tick) public ticks; /// @dev price ticks with delta values
    mapping(uint256 => CoverPosition) public positions0; //positions with token0 deposited
    mapping(uint256 => CoverPosition) public positions1; //positions with token1 deposited
}
