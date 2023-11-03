// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/external/uniswap/v3/IUniswapV3Factory.sol';
import '../../interfaces/external/uniswap/v3/IUniswapV3Pool.sol';
import '../../base/events/TwapSourceEvents.sol';
import '../../interfaces/cover/ICoverPool.sol';
import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/modules/sources/ITwapSource.sol';
import '../math/ConstantProduct.sol';

contract UniswapV3Source is ITwapSource, TwapSourceEvents {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    address public immutable uniV3Factory;
    uint16 public constant oneSecond = 1000;

    constructor(
        address _uniV3Factory
    ) {
        uniV3Factory = _uniV3Factory;
    }

    function initialize(
        PoolsharkStructs.CoverImmutables memory constants
    ) external returns (
        uint8 initializable,
        int24 startingTick
    )
    {
        // get the number of blocks covered by the twapLength
        uint16 blockCount = constants.twapLength * oneSecond / constants.sampleInterval;
        (
            uint16 cardinality,
            uint16 cardinalityNext
        ) = _getObservationsCardinality(constants.inputPool);
        if (cardinalityNext < blockCount) {
            _increaseV3Observations(constants.inputPool, blockCount);
            emit SampleCountInitialized(
                msg.sender,
                cardinality,
                cardinalityNext,
                blockCount
            );
            return (0, 0);
        } else if (cardinality < blockCount) {
            return (0, 0);
        }
        emit SampleCountInitialized(
            msg.sender,
            cardinality,
            cardinalityNext,
            blockCount
        );
        // ready to initialize if we get here
        initializable = 1;
        int24[4] memory averageTicks = calculateAverageTicks(constants);
        // take the average of the 4 samples as a starting tick
        startingTick = (averageTicks[0] + averageTicks[1] + averageTicks[2] + averageTicks[3]) / 4;
    }

    function factory() external view returns (address) {
        return uniV3Factory;
    }

    function feeTierTickSpacing(
        uint16 feeTier
    ) external view returns (
        int24
    )
    {
        return IUniswapV3Factory(uniV3Factory).feeTierTickSpacing(feeTier);
    }

    function getPool(
        address token0,
        address token1,
        uint16 feeTier
    ) external view returns(
        address pool
    ) {
        return IUniswapV3Factory(uniV3Factory).getPool(token0, token1, feeTier);
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
        uint32 timeDelta = (constants.sampleInterval / oneSecond == 0) ? 2 
                                                                : constants.sampleInterval * 2 / oneSecond;
        secondsAgos[0] = 0;
        secondsAgos[1] = timeDelta;
        secondsAgos[2] = constants.twapLength - timeDelta;
        secondsAgos[3] = constants.twapLength;
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(constants.inputPool).observe(secondsAgos);
        
        // take the smallest absolute value of 4 samples
        averageTicks[0] = int24(((tickCumulatives[0] - tickCumulatives[2]) / (int32(secondsAgos[2] - secondsAgos[0]))));
        averageTicks[1] = int24(((tickCumulatives[0] - tickCumulatives[3]) / (int32(secondsAgos[3] - secondsAgos[0]))));
        averageTicks[2] = int24(((tickCumulatives[1] - tickCumulatives[2]) / (int32(secondsAgos[2] - secondsAgos[1]))));
        averageTicks[3] = int24(((tickCumulatives[1] - tickCumulatives[3]) / (int32(secondsAgos[3] - secondsAgos[1]))));

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
        
        uint16 samplesRequired = uint16(constants.twapLength) * oneSecond / constants.sampleInterval;
        (
            uint16 sampleCount,
            uint16 sampleCountMax
        ) = _getObservationsCardinality(constants.inputPool);

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

    function _getObservationsCardinality(
        address pool
    ) internal view returns (
        uint16 cardinality,
        uint16 cardinalityNext
    )
    {
        (, , , cardinality, cardinalityNext, , ) = IUniswapV3Pool(pool).slot0();
    }

    function _increaseV3Observations(address pool, uint32 blockCount) internal {
        IUniswapV3Pool(pool).increaseObservationCardinalityNext(uint16(blockCount));
    }
}
