// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../../interfaces/ICoverPoolFactory.sol';
import '../../utils/CoverPoolErrors.sol';

abstract contract CoverPoolStorage is ICoverPoolStructs, CoverPoolErrors {
    GlobalState public globalState;
    PoolState public pool0; /// @dev State for token0 as output
    PoolState public pool1; /// @dev State for token1 as output

    address public feeTo;

    TickMap public tickMap;
    mapping(int24 => TickNode) public tickNodes; /// @dev Tick nodes in linked list

    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions0; //positions with token0 deposited
    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions1; //positions with token1 deposited
}
