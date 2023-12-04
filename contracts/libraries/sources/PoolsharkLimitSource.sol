// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/limit/ILimitPoolManager.sol';
import '../../interfaces/limit/ILimitPoolFactory.sol';
import '../../interfaces/limit/ILimitPool.sol';
import '../../base/events/TwapSourceEvents.sol';
import '../../interfaces/cover/ICoverPool.sol';
import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/modules/sources/ITwapSource.sol';
import '../math/ConstantProduct.sol';

contract PoolsharkLimitSource is ITwapSource, TwapSourceEvents {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    // poolType on limitPoolFactory
    uint16 public immutable poolType;
    address public immutable limitPoolFactory;
    address public immutable limitPoolManager;
    uint16 public constant oneSecond = 1000;

    constructor(
        address _limitPoolFactory,
        address _limitPoolManager,
        uint16 _poolType
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
        // get the number of samples covered by the twapLength
        uint16 samplesRequired = uint16(constants.twapLength) * oneSecond / constants.sampleInterval;
        (
            uint16 sampleCount,
            uint16 sampleCountMax
        ) = _getSampleCount(constants.inputPool);

        emit SampleCountInitialized (
            msg.sender,
            sampleCount,
            sampleCountMax,
            samplesRequired
        );

        if (sampleCountMax < samplesRequired) {
            _increaseSampleCount(constants.inputPool, samplesRequired);
            return (0, 0);
        } else if (sampleCount < samplesRequired) {
            return (0, 0);
        }
         // ready to initialize
        initializable = 1;
        int24[4] memory averageTicks = calculateAverageTicks(constants);
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
        (pool,) = ILimitPoolFactory(limitPoolFactory).getLimitPool(token0, token1, feeTier, poolType);
    }

    function calculateAverageTick(
        PoolsharkStructs.CoverImmutables memory constants,
        int24 latestTick
    ) external view returns (
        int24 averageTick
    )
    {
        int24[4] memory averageTicks = calculateAverageTicks(constants);
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

    function calculateAverageTicks(
        PoolsharkStructs.CoverImmutables memory constants
    ) public view returns (
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

    function syncLatestTick(
        PoolsharkStructs.CoverImmutables memory constants,
        address coverPool
    ) external view returns (
        int24 latestTick,
        bool twapReady
    ) {
        if (constants.inputPool == address(0))
            return (0, false);
        (
            uint16 sampleCount,
            uint16 sampleCountMax
        ) = _getSampleCount(constants.inputPool);

        // check twap readiness
        uint16 samplesRequired = uint16(constants.twapLength) * 
                                    oneSecond / constants.sampleInterval;
        if (sampleCountMax < samplesRequired) {
            return (0, false);
        } else if (sampleCount < samplesRequired) {
            return (0, false);
        }
        // ready to initialize
        twapReady = true;

        // if pool exists check unlocked state
        uint8 unlockedState = 0;
        if (coverPool != address(0)) {
            CoverPoolStructs.GlobalState memory state = ICoverPool(coverPool).syncGlobalState();
            unlockedState = state.unlocked;
        }
        if (unlockedState == 0) {
            // pool uninitialized
            int24[4] memory averageTicks = calculateAverageTicks(constants);
            // take the average of the 4 samples as a starting tick
            latestTick = (averageTicks[0] + averageTicks[1] + averageTicks[2] + averageTicks[3]) / 4;
            latestTick = (latestTick / int24(constants.tickSpread)) * int24(constants.tickSpread);
        } else {
            // pool initialized
            latestTick = ICoverPool(coverPool).syncLatestTick();
        }
    }

    function _getSampleCount(
        address pool
    ) internal view returns (
        uint16 sampleCount,
        uint16 sampleCountMax
    )
    {
        (
            ILimitPool.RangePoolState memory poolState,
            ,,,,,
        ) = ILimitPool(pool).globalState();
        
        sampleCount = poolState.samples.count;
        sampleCountMax = poolState.samples.countMax;
    }

    function _increaseSampleCount(address pool, uint32 blockCount) internal {
        ILimitPool(pool).increaseSampleCount(uint16(blockCount));
    }
}
