// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../../interfaces/external/IUniswapV3Factory.sol';
import '../../interfaces/external/IUniswapV3Pool.sol';
import '../../interfaces/ICoverPoolStructs.sol';
import '../../interfaces/modules/ITwapSource.sol';
import '../../libraries/math/TickMath.sol';

contract UniswapV3Source is ITwapSource {
    error WaitUntilBelowMaxTick();
    error WaitUntilAboveMinTick();

    address public immutable uniV3Factory;
    /// @dev - set for Arbitrum mainnet
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
        return (1, _calculateAverageTick(constants.inputPool, constants.twapLength));
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
        address pool,
        uint16 twapLength
    ) external view returns (
        int24 averageTick
    )
    {
        return _calculateAverageTick(pool, twapLength);
    }

    function _calculateAverageTick(
        address pool,
        uint16 twapLength
    ) internal view returns (
        int24 averageTick
    )
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;
        secondsAgos[1] = twapLength;
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);
        averageTick = int24(((tickCumulatives[0] - tickCumulatives[1]) / (int32(secondsAgos[1]))));
        //TODO: this should be limited to TickMath.MAX_TICK / tickSpread * tickSpread
        if (averageTick == TickMath.MAX_TICK) revert WaitUntilBelowMaxTick();
        if (averageTick == TickMath.MIN_TICK) revert WaitUntilAboveMinTick();
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
