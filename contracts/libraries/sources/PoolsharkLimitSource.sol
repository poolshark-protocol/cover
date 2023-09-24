// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/external/poolshark/limit/ILimitPoolManager.sol';
import '../../interfaces/external/poolshark/limit/ILimitPoolFactory.sol';
import '../../interfaces/external/poolshark/limit/ILimitPool.sol';
import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/modules/sources/ITwapSource.sol';
import '../math/ConstantProduct.sol';

contract PoolsharkLimitSource is ITwapSource {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    // poolType on limitPoolFactory
    bytes32 public immutable poolType;
    address public immutable limitPoolFactory;
    address public immutable limitPoolManager;
    uint16 public constant oneSecond = 1000;

    event SampleCountInitialized (
        uint16 sampleCount,
        uint16 sampleCountMax,
        uint16 sampleCountRequired
    );

    constructor(
        address _limitPoolFactory,
        address _limitPoolManager,
        bytes32 _poolType
    ) {
        limitPoolFactory = _limitPoolFactory;
        limitPoolManager = _limitPoolManager;
        poolType = _poolType;
    }

    function initialize(
        PoolsharkStructs.CoverImmutables memory constants
    ) external returns (
        uint8 initializable,
        int24 startingTick
    )
    {
        // get the number of blocks covered by the twapLength
        uint16 blockCount = uint16(constants.twapLength) * oneSecond / constants.sampleInterval;
        (
            uint16 sampleCount,
            uint16 sampleCountMax
        ) = _getSampleCount(constants.inputPool);

        if (sampleCountMax < blockCount) {
            _increaseSampleCount(constants.inputPool, blockCount);
            emit SampleCountInitialized (
                sampleCount,
                sampleCountMax,
                blockCount
            );
            return (0, 0);
        } else if (sampleCount < blockCount) {
            return (0, 0);
        }
        emit SampleCountInitialized (
            sampleCount,
            sampleCountMax,
            blockCount
        );
         // ready to initialize
        initializable = 1;
        int24[4] memory averageTicks = _calculateAverageTicks(constants);
        // take the average of the 4 samples as a starting tick
        startingTick = (averageTicks[0] + averageTicks[1] + averageTicks[2] + averageTicks[3]) / 4;
    }

    function factory() external view returns (address) {
        return limitPoolFactory;
    }

    function feeTierTickSpacing(
        uint16 feeTier
    ) external view returns (
        int24
    )
    {
        return int24(ILimitPoolManager(limitPoolManager).feeTiers(feeTier));
    }

    function getPool(
        address token0,
        address token1,
        uint16 feeTier
    ) external view returns(
        address pool
    ) {
        (pool,) = ILimitPoolFactory(limitPoolFactory).getLimitPool(poolType, token0, token1, feeTier);
    }

    function calculateAverageTick(
        PoolsharkStructs.CoverImmutables memory constants,
        int24 latestTick
    ) external view returns (
        int24 averageTick
    )
    {
        int24[4] memory averageTicks = _calculateAverageTicks(constants);
        int24 minTickVariance = ConstantProduct.maxTick(constants.tickSpread) * 2;
        for (uint i; i < 4; i++) {
            int24 absTickVariance = latestTick - averageTicks[i] >= 0 ? latestTick - averageTicks[i]
                                                                     : averageTicks[i] - latestTick;
            if (absTickVariance <= minTickVariance) {
                /// @dev - averageTick has the least possible variance from latestTick
                minTickVariance = absTickVariance;
                averageTick = averageTicks[i];
            }
        }
    }

    function _calculateAverageTicks(
        PoolsharkStructs.CoverImmutables memory constants
    ) internal view returns (
        int24[4] memory averageTicks
    )
    {
        uint32[] memory secondsAgos = new uint32[](4);
        /// @dev - take 4 samples
        /// @dev - twapLength must be >= 5 * sampleInterval
        uint32 timeDelta = constants.sampleInterval / oneSecond == 0 ? 2
                                                                : constants.sampleInterval * 2 / oneSecond; 
        secondsAgos[0] = 0;
        secondsAgos[1] = timeDelta;
        secondsAgos[2] = constants.twapLength - timeDelta;
        secondsAgos[3] = constants.twapLength;
        (int56[] memory tickSecondsAccum,,,,) = ILimitPool(constants.inputPool).sample(secondsAgos);
        
          /// @dev take the smallest absolute value of 4 samples
        averageTicks[0] = int24(((tickSecondsAccum[0] - tickSecondsAccum[2]) / (int32(secondsAgos[2] - secondsAgos[0]))));
        averageTicks[1] = int24(((tickSecondsAccum[0] - tickSecondsAccum[3]) / (int32(secondsAgos[3] - secondsAgos[0]))));
        averageTicks[2] = int24(((tickSecondsAccum[1] - tickSecondsAccum[2]) / (int32(secondsAgos[2] - secondsAgos[1]))));
        averageTicks[3] = int24(((tickSecondsAccum[1] - tickSecondsAccum[3]) / (int32(secondsAgos[3] - secondsAgos[1]))));

        // make sure all samples fit within min/max bounds
        int24 minAverageTick = ConstantProduct.minTick(constants.tickSpread) + constants.tickSpread;
        int24 maxAverageTick = ConstantProduct.maxTick(constants.tickSpread) - constants.tickSpread;
        for (uint i; i < 4; i++) {
            if (averageTicks[i] < minAverageTick)
                averageTicks[i] = minAverageTick;
            if (averageTicks[i] > maxAverageTick)
                averageTicks[i] = maxAverageTick;
        }
    }

    function _getSampleCount(
        address pool
    ) internal view returns (
        uint16,
        uint16
    )
    {
        (
            ILimitPool.RangePoolState memory poolState,
            ,,,,,
        ) = ILimitPool(pool).globalState();
        return (
            poolState.samples.count,
            poolState.samples.countMax
        );
    }

    function _increaseSampleCount(address pool, uint32 blockCount) internal {
        ILimitPool(pool).increaseSampleCount(uint16(blockCount));
    }
}
