// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../interfaces/modules/curves/ICurveMath.sol';
import '../interfaces/ICoverPoolStructs.sol';

library EpochMap {
    function set(
        int24  tick,
        uint256 epoch,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.Immutables memory constants
    ) external {
        (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        ) = getIndices(tick, constants);
        // assert epoch isn't bigger than max uint32
        uint256 epochValue = tickMap.epochs[volumeIndex][blockIndex][wordIndex];
        // clear previous value
        epochValue &=  ~(((1 << 9) - 1) << ((tickIndex & 0x7) * 32));
        // add new value to word
        epochValue |= epoch << ((tickIndex & 0x7) * 32);
        // store word in map
        tickMap.epochs[volumeIndex][blockIndex][wordIndex] = epochValue;
    }

    function unset(
        int24 tick,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.Immutables memory constants
    ) external {
        (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        ) = getIndices(tick, constants);

        uint256 epochValue = tickMap.epochs[volumeIndex][blockIndex][wordIndex];
        // clear previous value
        epochValue &= ~(1 << (tickIndex & 0x7 * 32) - 1);
        // store word in map
        tickMap.epochs[volumeIndex][blockIndex][wordIndex] = epochValue;
    }

    function get(
        int24 tick,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        uint32 epoch
    ) {
        (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        ) = getIndices(tick, constants);

        uint256 epochValue = tickMap.epochs[volumeIndex][blockIndex][wordIndex];
        // right shift so first 8 bits are epoch value
        epochValue >>= ((tickIndex & 0x7) * 32);
        // clear other bits
        epochValue &= ((1 << 32) - 1);
        return uint32(epochValue);
    }

    function getIndices(
        int24 tick,
        ICoverPoolStructs.Immutables memory constants
    ) public pure returns (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        )
    {
        unchecked {
            if (tick > constants.curve.maxTick(constants.tickSpread)) require (false, 'TickIndexOverflow()');
            if (tick < constants.curve.minTick(constants.tickSpread)) require (false, 'TickIndexUnderflow()');
            if (tick % constants.tickSpread != 0) require (false, 'TickIndexInvalid()');
            tickIndex = uint256(int256((tick - constants.curve.minTick(constants.tickSpread))) / constants.tickSpread);
            wordIndex = tickIndex >> 3;        // 2^3 epochs per word
            blockIndex = tickIndex >> 11;      // 2^8 words per block
            volumeIndex = tickIndex >> 19;     // 2^8 blocks per volume
            if (blockIndex > 1023) require (false, 'BlockIndexOverflow()');
        }
    }

    function _tick (
        uint256 tickIndex,
        ICoverPoolStructs.Immutables memory constants
    ) internal pure returns (
        int24 tick
    ) {
        unchecked {
            if (tickIndex > uint24(constants.curve.maxTick(constants.tickSpread) * 2)) require (false, 'TickIndexOverflow()');
            tick = int24(int256(tickIndex) * int256(constants.tickSpread) + constants.curve.maxTick(constants.tickSpread));
        }
    }
}
