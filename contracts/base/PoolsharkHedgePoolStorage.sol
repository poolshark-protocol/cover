// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../interfaces/IPoolsharkHedgePoolFactory.sol";
import "../utils/PoolsharkErrors.sol";
import "../libraries/Ticks.sol";

abstract contract PoolsharkHedgePoolStorage is IPoolsharkHedgePoolStructs, PoolsharkHedgePoolErrors {
    uint256 internal unlocked;

    address internal feeTo;

    uint24 internal constant MAX_FEE = 10000; /// @dev Equivalent to 1%.
    /// @dev Reference: tickSpacing of 100 -> 2% between ticks.

    uint128 public liquidity;

    uint160 internal secondsGrowthGlobal; /// @dev Multiplied by 2^128.
    uint32 internal lastObservation;

    uint256 public feeGrowthGlobal; /// @dev All fee growth counters are multiplied by 2^128.
    uint256 public feeGrowthGlobalLast;

    uint128 internal tokenInProtocolFee;
    uint128 internal tokenOutProtocolFee;

    uint160 internal sqrtPrice; /// @dev Sqrt of price aka. √(y/x), multiplied by 2^96.
    
    int24 internal nearestTick; /// @dev Tick that is just below the current price.

    mapping(int24 => Tick) public ticks;
    mapping(address => mapping(int24 => mapping(int24 => Position))) public positions;
    
}
    
    
