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

    uint128 public liquidity;

    uint160 public secondsGrowthGlobal; /// @dev Multiplied by 2^128.
    uint256 public lastBlockNumber;

    uint256 public feeGrowthGlobal; /// @dev All fee growth counters are multiplied by 2^128.
    uint256 public feeGrowthGlobalLast;

    uint128 public tokenInProtocolFee;
    uint128 public tokenOutProtocolFee;

    uint160 public sqrtPrice; /// @dev Sqrt of price aka. √(y/x), multiplied by 2^96.
    
    int24 public latestTick;  /// @dev Tick externally sourced at the latest block.
    int24 public nearestTick; /// @dev Tick that is just below the current price.

    mapping(int24 => Tick) public ticks;
    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions;
}
    
    
