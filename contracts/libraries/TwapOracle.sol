// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../interfaces/IRangeFactory.sol';
import '../interfaces/IRangePool.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './math/TickMath.sol';

// will the blockTimestamp be consistent across the entire block?
library TwapOracle {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();
    /// @dev - set for Arbitrum mainnet
    uint32 public constant oneSecond = 1000;

    // @dev increase pool observations if not sufficient
    // @dev must be deterministic since called externally
    function initializePoolObservations(
        IRangePool pool,
        uint16 twapLength,
        ICoverPoolStructs.Immutables memory constants
    ) external returns (
        uint8 initializable,
        int24 startingTick
    )
    {
        // get the number of blocks covered by the twapLength
        uint32 blockCount = uint32(twapLength) * uint32(constants.blockTime) / oneSecond;
        if (!_isPoolObservationsEnough(pool, blockCount)) {
            _increaseV3Observations(address(pool), blockCount);
            return (0, 0);
        }
        return (1, _calculateAverageTick(pool, twapLength, constants));
    }

    function calculateAverageTick(
        IRangePool pool,
        uint16 twapLength,
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        int24 averageTick
    )
    {
        return _calculateAverageTick(pool, twapLength, constants);
    }

    function _calculateAverageTick(
        IRangePool pool,
        uint16 twapLength,
        ICoverPoolStructs.Immutables memory constants
    ) internal view returns (
        int24 averageTick
    )
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;
        secondsAgos[1] = constants.blockTime * twapLength;
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        averageTick = int24(((tickCumulatives[0] - tickCumulatives[1]) / (int32(secondsAgos[1]))));
        if (averageTick == TickMath.MAX_TICK) revert WaitUntilBelowMaxTick();
        if (averageTick == TickMath.MIN_TICK) revert WaitUntilAboveMinTick();
    }

    function isPoolObservationsEnough(address pool, uint32 blockCount)
        external
        view
        returns (bool)
    {
        return _isPoolObservationsEnough(IRangePool(pool), blockCount);
    }

    function _isPoolObservationsEnough(IRangePool pool, uint32 blockCount)
        internal
        view
        returns (bool)
    {
        (, , , uint16 observationsCount, , , ) = pool.slot0();
        return observationsCount >= blockCount;
    }

    function _increaseV3Observations(address pool, uint32 blockCount) internal {
        IRangePool(pool).increaseObservationCardinalityNext(uint16(blockCount));
    }
}
