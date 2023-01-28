// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRangeFactory.sol";
import "../interfaces/IRangePool.sol";
import "./TickMath.sol";
import "hardhat/console.sol";

// will the blockTimestamp be consistent across the entire block?
library TwapOracle
{
    uint16 public constant blockTime = 12;

    // @dev increase pool observations if not sufficient
    // @dev must be deterministic since called externally
    function initializePoolObservations(IRangePool pool, uint16 twapLength) external returns (uint8 initializable, int24 startingTick) {
        if (!_isPoolObservationsEnough(pool, twapLength)) {
            _increaseV3Observations(address(pool), twapLength);
            return (0, 0);
        }
        return (1, _calculateAverageTick(pool, twapLength));
    }

    function calculateAverageTick(IRangePool pool, uint16 twapLength) external view returns (int24 averageTick) {
        return _calculateAverageTick(pool, twapLength);
    }

    function _calculateAverageTick(IRangePool pool, uint16 twapLength) internal view returns (int24 averageTick) {
        uint32[] memory secondsAgos = new uint32[](3);
        secondsAgos[0] = 0;
        secondsAgos[1] = blockTime * twapLength;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        averageTick = int24(((tickCumulatives[0] - tickCumulatives[1]) / (int32(secondsAgos[1]))));
    }

    function isPoolObservationsEnough(address pool, uint16 twapLength) external view returns (bool) {
        return _isPoolObservationsEnough(IRangePool(pool), twapLength);
    }

    function _isPoolObservationsEnough(IRangePool pool, uint16 twapLength) internal view returns (bool){
        (,,,uint16 observationsCount,,,) = pool.slot0();
        return observationsCount >= twapLength;
    }

    function _increaseV3Observations(address pool, uint16 twapLength) internal {
        IRangePool(pool).increaseObservationCardinalityNext(twapLength);
    }
}