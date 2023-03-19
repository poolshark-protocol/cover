// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import '../interfaces/ICoverPoolStructs.sol';

library TickBitmap {

    error TickIndexOverflow();
    error TickIndexUnderflow();
    error BlockIndexOverflow();

    function _getIndices(
        int24 tick
    ) internal pure returns (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        )
    {
        unchecked {
            if (tick > TickMath.MAX_TICK) revert TickIndexOverflow();
            if (tick < TickMath.MIN_TICK) revert TickIndexUnderflow();
            tickIndex = uint256(int256((tick - TickMath.MIN_TICK)));
            wordIndex = tickIndex >> 4;        // 2^4 epochs per word
            blockIndex = tickIndex >> 12;      // 2^8 words per block
            volumeIndex = tickIndex >> 20;     // 2^8 blocks per volume
            if (blockIndex > 1023) revert BlockIndexOverflow();
        }
    }

    function _tick (
        uint256 tickIndex
    ) internal pure returns (
        int24 tick
    ) {
        unchecked {
            if (tickIndex > uint24(TickMath.MAX_TICK * 2)) revert TickIndexOverflow();
            tick = int24(int256(tickIndex) + TickMath.MIN_TICK);
        }
    }

    function _set(
        ICoverPoolStructs.TickMap storage tickMap,
        int24  tick,
        uint256 epoch
    ) internal {
        (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        ) = _getIndices(tick);

        uint256 epochValue = tickMap.epochs[volumeIndex][blockIndex][wordIndex];
        // clear previous value
        epochValue &= ~(1 << (tickIndex & 0x7 * 8) - 1);
        // add new value to word
        epochValue &= epoch << (tickIndex & 0x7 * 8);
        // store word in map
        tickMap.epochs[volumeIndex][blockIndex][wordIndex] = epochValue;
    }

    function unset(
        ICoverPoolStructs.TickMap storage tickMap,
        int24 tick
    ) internal {
        (
            uint256 tickIndex,
            uint256 wordIndex,
            uint256 blockIndex,
            uint256 volumeIndex
        ) = _getIndices(tick);

        uint256 epochValue = tickMap.epochs[volumeIndex][blockIndex][wordIndex];
        // clear previous value
        epochValue &= ~(1 << (tickIndex & 0x7 * 8) - 1);
        // store word in map
        tickMap.epochs[volumeIndex][blockIndex][wordIndex] = epochValue;
    }
}
