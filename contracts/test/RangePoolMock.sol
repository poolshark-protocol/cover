//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import '../interfaces/external/poolshark/range/IRangePool.sol';
import './UniswapV3PoolMock.sol';

contract RangePoolMock is IRangePool {
    address internal admin;
    address public token0;
    address public token1;
    int24 public tickSpacing;
    uint256 swapFee;

    uint16 observationCardinality;
    uint16 observationCardinalityNext;

    int56 tickCumulative0;
    int56 tickCumulative1;
    int56 tickCumulative2;
    int56 tickCumulative3;

    constructor(
        address _token0,
        address _token1,
        uint24 _swapFee,
        int24 _tickSpacing
    ) {
        require(_token0 < _token1, 'wrong token order');
        admin = msg.sender;
        token0 = _token0;
        token1 = _token1;
        swapFee = _swapFee;
        tickSpacing = _tickSpacing;
        observationCardinality = 4;
        observationCardinalityNext = 4;
        tickCumulative0 = 10;
        tickCumulative1 = 9;
        tickCumulative2 = 6;
        tickCumulative3 = 5;
    }

    function poolState()
        external
        view override
        returns (
            uint8,
            uint16,
            int24,
            int56,
            uint160,
            uint160,
            uint128,
            uint128,
            uint200,
            uint200,
            SampleState memory,
            ProtocolFees memory
        )
    {
        return (
            1,
            0,
            0,
            0,
            0,
            1 << 96,
            0,
            0,
            0,
            0,
            SampleState(
                4,
                observationCardinality,
                observationCardinalityNext
            ),
            ProtocolFees(0,0)
        );
    }

    function sample(
        uint32[] calldata secondsAgos
    ) external view override returns (
            int56[]   memory tickSecondsAccum,
            uint160[] memory secondsPerLiquidityAccum,
            uint160 averagePrice,
            uint128 averageLiquidity,
            int24 averageTick
        )
    {
        secondsAgos;
        tickSecondsAccum = new int56[](secondsAgos.length);
        tickSecondsAccum[0] = int56(tickCumulative0);
        tickSecondsAccum[1] = int56(tickCumulative1);
        tickSecondsAccum[2] = int56(tickCumulative2);
        tickSecondsAccum[3] = int56(tickCumulative3);
        secondsPerLiquidityAccum = new uint160[](secondsAgos.length);
        secondsPerLiquidityAccum[0] = uint160(949568451203788412348119);
        secondsPerLiquidityAccum[1] = uint160(949568451203788412348119);
        secondsPerLiquidityAccum[2] = uint160(949568438263103965182699);
        secondsPerLiquidityAccum[3] = uint160(949568438263103965182699);
    }

    function increaseSampleLength(uint16 cardinalityNext) external {
        observationCardinalityNext = cardinalityNext;
    }

    function setTickCumulatives(int56 _tickCumulative0, int56 _tickCumulative1, int56 _tickCumulative2, int56 _tickCumulative3) external {
        tickCumulative0 = _tickCumulative0;
        tickCumulative1 = _tickCumulative1;
        tickCumulative2 = _tickCumulative2;
        tickCumulative3 = _tickCumulative3;
    }

    function setObservationCardinality(uint16 _observationCardinality, uint16 _observationCardinalityNext) external {
        observationCardinality = _observationCardinality;
        observationCardinalityNext = _observationCardinalityNext;
    }
}
