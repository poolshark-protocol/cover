// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/utils/ITwapOracle.sol";
import "../../interfaces/IRangeFactory.sol";
import "../../interfaces/IRangePool.sol";
import "../../utils/SafeTransfers.sol";
import "../../libraries/TickMath.sol";
import "hardhat/console.sol";

// will the blockTimestamp be consistent across the entire block?
abstract contract TwapOracle is 
    ITwapOracle
{
    IRangeFactory public concentratedFactory;
    //TODO: set from constructor
    uint16 private constant observationsLength = 5;
    uint16 private constant blockTime = 12;
    int24  private constant invalidTick = -887273; /// @dev = MIN_TICK - 1

    // @dev increase pool observations if not sufficient
    // @dev must be deterministic since called externally
    function initializePoolObservations(IRangePool pool) external returns (uint8 initializable, int24 startingTick) {
        if (!_isPoolObservationsEnough(pool)) {
            _increaseV3Observations(address(pool));
            return (0, 0);
        }
        return (1, _calculateAverageTick(pool));
    }

    function calculateAverageTick(IRangePool pool) external view returns (int24 averageTick) {
        return _calculateAverageTick(pool);
    }

    function _calculateAverageTick(IRangePool pool) internal view returns (int24 averageTick) {
        uint32[] memory secondsAgos = new uint32[](3);
        secondsAgos[0] = 0;
        secondsAgos[1] = blockTime * observationsLength;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        averageTick = int24(((tickCumulatives[0] - tickCumulatives[1]) / (int32(secondsAgos[1]))));
    }

    function isPoolObservationsEnough(IRangePool pool) external view returns (bool) {
        return _isPoolObservationsEnough(pool);
    }

    function _isPoolObservationsEnough(IRangePool pool) internal view returns (bool){
        (,,,,uint16 observationsCount,,) = pool.slot0();
        return observationsCount >= observationsLength;
    }

    function _increaseV3Observations(address pool) internal {
        IRangePool(pool).increaseObservationCardinalityNext(observationsLength);
    }

    function getSqrtPriceLimitX96(bool zeroForOne) external pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
    }
}