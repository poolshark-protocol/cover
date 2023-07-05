// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IRangePool {

    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }
    
    struct SampleState {
        uint16  index;
        uint16  length;
        uint16  lengthNext;
    }

    function sample(
        uint32[] memory secondsAgo
    ) external view returns (
        int56[]   memory tickSecondsAccum,
        uint160[] memory secondsPerLiquidityAccum,
        uint160 averagePrice,
        uint128 averageLiquidity,
        int24 averageTick
    );

    function increaseSampleLength(
        uint16 sampleLengthNext
    ) external;

    function poolState() external view returns (
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
    );
}
