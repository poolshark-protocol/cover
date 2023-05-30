// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/external/poolshark/range/IRangePoolManager.sol';
import '../../interfaces/external/poolshark/range/IRangePoolFactory.sol';
import '../../interfaces/external/poolshark/range/IRangePool.sol';
import '../../interfaces/ICoverPoolStructs.sol';
import '../../interfaces/modules/sources/ITwapSource.sol';
import '../math/ConstantProduct.sol';

contract PoolsharkRangeSource is ITwapSource {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    address public immutable rangePoolFactory;
    address public immutable rangePoolManager;
    /// @dev - set for Arbitrum mainnet
    uint32 public constant oneSecond = 1000;

    constructor(
        address _rangePoolFactory,
        address _rangePoolManager
    ) {
        rangePoolFactory = _rangePoolFactory;
        rangePoolManager = _rangePoolManager;
    }

    function initialize(
        ICoverPoolStructs.Immutables memory constants
    ) external returns (
        uint8 initializable,
        int24 startingTick
    )
    {
        // get the number of blocks covered by the twapLength
        uint32 blockCount = uint32(constants.twapLength) * oneSecond / constants.blockTime;
        (
            bool sampleCountEnough,
            bool sampleLengthEnough
        ) = _isPoolSamplesEnough(
                constants.inputPool,
                blockCount
        );
        if (!sampleLengthEnough) {
            _increaseSampleLength(constants.inputPool, blockCount);
            return (0, 0);
        } else if (!sampleCountEnough) {
            return (0, 0);
        }
        return (1, _calculateAverageTick(constants));
    }

    function factory() external view returns (address) {
        return rangePoolFactory;
    }

    function feeTierTickSpacing(
        uint16 feeTier
    ) external view returns (
        int24
    )
    {
        return IRangePoolManager(rangePoolManager).feeTiers(feeTier);
    }

    function getPool(
        address token0,
        address token1,
        uint16 feeTier
    ) external view returns(
        address pool
    ) {
        return IRangePoolFactory(rangePoolFactory).getRangePool(token0, token1, feeTier);
    }

    function calculateAverageTick(
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        int24 averageTick
    )
    {
        return _calculateAverageTick(constants);
    }

    function _calculateAverageTick(
        ICoverPoolStructs.Immutables memory constants
    ) internal view returns (
        int24 averageTick
    )
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;
        secondsAgos[1] = constants.twapLength;
        (int56[] memory tickSecondsAccum, ) = IRangePool(constants.inputPool).sample(secondsAgos);
        averageTick = int24(((tickSecondsAccum[0] - tickSecondsAccum[1]) / (int32(secondsAgos[1]))));
        int24 maxAverageTick = ConstantProduct.maxTick(constants.tickSpread) - constants.tickSpread;
        if (averageTick > maxAverageTick) return maxAverageTick;
        int24 minAverageTick = ConstantProduct.minTick(constants.tickSpread) + constants.tickSpread;
        if (averageTick < minAverageTick) return minAverageTick;
    }

    function _isPoolSamplesEnough(
        address pool,
        uint32 blockCount
    ) internal view returns (
        bool,
        bool
    )
    {
        (
            ,,,,,,,,,,
            IRangePool.SampleState memory samples,
        ) = IRangePool(pool).poolState();
        return (samples.length >= blockCount, samples.lengthNext >= blockCount);
    }

    function _increaseSampleLength(address pool, uint32 blockCount) internal {
        IRangePool(pool).increaseSampleLength(uint16(blockCount));
    }
}
