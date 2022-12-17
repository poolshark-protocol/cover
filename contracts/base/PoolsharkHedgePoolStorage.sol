// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../interfaces/IPoolsharkHedgePoolFactory.sol";
import "../interfaces/IPoolsharkUtils.sol";
import "../utils/PoolsharkErrors.sol";
import "../libraries/Ticks.sol";

abstract contract PoolsharkHedgePoolStorage is IPoolsharkHedgePoolStructs, PoolsharkHedgePoolErrors {
    uint256 internal unlocked;

    IPoolsharkUtils public utils;
    address public feeTo;

    uint24 internal constant MAX_FEE = 10000; /// @dev Equivalent to 1%.
    /// @dev Reference: tickSpacing of 100 -> 2% between ticks.

    PoolState public pool0; /// @dev State for token0 as output
    PoolState public pool1; /// @dev State for token1 as output
    int24 public latestTick; /// @dev Latest updated inputPool price tick
    uint256 public lastBlockNumber;
    uint256 public feeGrowthGlobalIn0;
    uint256 public feeGrowthGlobalIn1;
    
    mapping(int24 => Tick) public ticks0; /// @dev Tick nodes in linked list
    mapping(int24 => Tick) public ticks1; /// @dev Ticks containing token0 as output
    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions0; //positions with token0 deposited
    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions1; //positions with token1 deposited
}
    
    
