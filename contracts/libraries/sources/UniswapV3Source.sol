// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/external/uniswap/v3/IUniswapV3Factory.sol';
import '../../interfaces/external/uniswap/v3/IUniswapV3Pool.sol';
import '../../interfaces/ICoverPoolStructs.sol';
import '../../interfaces/modules/sources/ITwapSource.sol';
import '../math/ConstantProduct.sol';

contract UniswapV3Source is ITwapSource {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    address public immutable uniV3Factory;
    uint32 public constant oneSecond = 1000;

    constructor(
        address _uniV3Factory
    ) {
        uniV3Factory = _uniV3Factory;
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
            bool observationsCountEnough,
            bool observationsLengthEnough
        ) = _isPoolObservationsEnough(
                constants.inputPool,
                blockCount
        );
        if (!observationsLengthEnough) {
            _increaseV3Observations(constants.inputPool, blockCount);
            return (0, 0);
        } else if (!observationsCountEnough) {
            return (0, 0);
        }
        return (1, _calculateAverageTicks(constants));
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

    function calculateAverageTicks(
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        int24 averageTick
    )
    {
        return _calculateAverageTicks(constants);
    }

    function _calculateAverageTicks(
        ICoverPoolStructs.Immutables memory constants,
        int24 latestTick
    ) internal view returns (
        int24[4] memory averageTicks
    )
    {
        uint32[] memory secondsAgos = new uint32[](4);
        /// @dev - take 4 samples
        /// @dev - twapLength must be >= 5 * blockTime
        secondsAgos[0] = 0;
        secondsAgos[1] = constants.blockTime;
        secondsAgos[2] = constants.twapLength;
        secondsAgos[3] = constants.twapLength - constants.blockTime;
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(constants.inputPool).observe(secondsAgos);
        
        /// @dev take the smallest absolute value of 4 samples
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

    function _isPoolObservationsEnough(
        address pool,
        uint32 blockCount
    ) internal view returns (
        bool,
        bool
    )
    {
        (, , , uint16 observationsCount, uint16 observationsLength, , ) = IUniswapV3Pool(pool).slot0();
        return (observationsCount >= blockCount, observationsLength >= blockCount);
    }

    function _increaseV3Observations(address pool, uint32 blockCount) internal {
        IUniswapV3Pool(pool).increaseObservationCardinalityNext(uint16(blockCount));
    }
}
