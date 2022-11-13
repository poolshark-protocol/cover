// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PoolsharkHedgePoolStorage.sol";
import "../interfaces/IPoolsharkHedgePoolStructs.sol";
import "../libraries/DyDxMath.sol";
import "../libraries/TickMath.sol";

abstract contract PoolsharkHedgePoolView is PoolsharkHedgePoolStorage {

    function getPriceAndNearestTicks() public view returns (uint160 _price0, uint160 _price1, int24 _nearestTick0, int24 _nearestTick1) {
        _price0 = sqrtPrice0;
        _price1 = sqrtPrice1;
        _nearestTick0 = nearestTick0;
        _nearestTick1 = nearestTick1;
    }

    function getTokenProtocolFees() public view returns (uint128 _token0ProtocolFee, uint128 _token1ProtocolFee) {
        _token0ProtocolFee = token0ProtocolFee;
        _token1ProtocolFee = token1ProtocolFee;
    }

    function getSecondsGrowthAndLastObservation() public view returns (uint160 _secondsGrowthGlobal, uint32 _lastObservation) {
        _secondsGrowthGlobal = secondsGrowthGlobal;
        _lastObservation = lastObservation;
    } 
}
    
    
