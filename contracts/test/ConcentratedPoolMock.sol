//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IConcentratedPool.sol";
import "./ConcentratedPoolMock.sol";

contract ConcentratedPoolMock is IConcentratedPool {

    address token0;
    address token1;

    uint16 observationCardinality;
    uint16 observationCardinalityNext;

    constructor(
        address tokenA,
        address tokenB,
        uint24 fee
    ) {
        require(tokenA < tokenB, "wrong token order");
        token0 = tokenA;
        token1 = tokenB;
    }

    function slot0()
    external view
    returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 cardinality,
        uint16 cardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return (
            1 << 96,
            0,
            4,
            4,
            5,
            100,
            true
        );
    }

    function observe(
        uint32[] calldata secondsAgos
    )
    external view
    returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {
        tickCumulatives[0] = -8880594632141;
        tickCumulatives[1] = -8880569762981;
        secondsPerLiquidityCumulativeX128s[0] = 949568451203788412348119;
        secondsPerLiquidityCumulativeX128s[1] = 949568438263103965182699;
    }

    function increaseObservationCardinalityNext(
        uint16 cardinalityNext
    ) external {
        observationCardinalityNext = cardinalityNext;
    }
}