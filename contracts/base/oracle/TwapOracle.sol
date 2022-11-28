// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/utils/ITwapOracle.sol";
import "../../interfaces/IConcentratedFactory.sol";
import "../../interfaces/IConcentratedPool.sol";
import "../../utils/SafeTransfers.sol";
import "../../libraries/TickMath.sol";
import "hardhat/console.sol";

// will the blockTimestamp be consistent across the entire block?
abstract contract TwapOracle is 
    ITwapOracle
{

    IConcentratedFactory public concentratedFactory;
    uint16 private constant observationsLength = 5;
    uint16 private constant blockTime = 12;

    function calculateAverageTick(IConcentratedPool pool) external view returns (int24 averageTick){
        uint32[] memory secondsAgos = new uint32[](3);
        secondsAgos[0] = 0;
        secondsAgos[1] = blockTime * observationsLength;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        averageTick = int24(((tickCumulatives[0] - tickCumulatives[1]) / (int32(secondsAgos[1]))));
    }

    function isPoolObservationsEnough(IConcentratedPool pool) external view returns (bool){
        (,,,,uint16 count,,) = pool.slot0();
        return count >= observationsLength;
    }

    function increaseV3Observation(address pool) external {
        IConcentratedPool(pool).increaseObservationCardinalityNext(observationsLength);
    }

    function getSqrtPriceLimitX96(bool zeroForOne) external pure returns (uint160) {
        return zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
    }
}