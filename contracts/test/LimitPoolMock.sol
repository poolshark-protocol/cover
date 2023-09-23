//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import '../interfaces/external/poolshark/limit/ILimitPool.sol';
import './UniswapV3PoolMock.sol';

contract LimitPoolMock is ILimitPool {
    address internal admin;
    address public token0;
    address public token1;
    int24 public tickSpacing;
    uint256 swapFee;

    uint16 sampleLength;
    uint16 sampleLengthNext;

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
        sampleLength = 4;
        sampleLengthNext = 4;
        tickCumulative0 = 10;
        tickCumulative1 = 9;
        tickCumulative2 = 6;
        tickCumulative3 = 5;
    }

    function globalState()
        external
        view override
        returns (
            RangePoolState memory pool,
            LimitPoolState memory pool0,
            LimitPoolState memory pool1,
            uint128 liquidityGlobal,
            uint32 positionIdNext,
            uint32 epoch,
            uint8 unlocked
        )
    {
        pool.samples = SampleState(
                4,
                sampleLength,
                sampleLengthNext
        );
        pool0;
        pool1;
        liquidityGlobal;
        positionIdNext;
        epoch;
        unlocked;
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
        averagePrice;
        averageLiquidity;
        averageTick;
    }

    function increaseSampleLength(uint16 cardinalityNext) external {
        sampleLengthNext = cardinalityNext;
    }

    function setTickCumulatives(int56 _tickCumulative0, int56 _tickCumulative1, int56 _tickCumulative2, int56 _tickCumulative3) external {
        tickCumulative0 = _tickCumulative0;
        tickCumulative1 = _tickCumulative1;
        tickCumulative2 = _tickCumulative2;
        tickCumulative3 = _tickCumulative3;
    }

    function setObservationCardinality(uint16 _sampleLength, uint16 _sampleLengthNext) external {
        sampleLength = _sampleLength;
        sampleLengthNext = _sampleLengthNext;
    }
}
