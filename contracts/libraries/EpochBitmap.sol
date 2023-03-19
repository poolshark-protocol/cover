// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import '../interfaces/ICoverPoolStructs.sol';

library EpochBitmap {

    error SetIndexOverflow();
    
    function _getIndices(
        int24 tick
    ) internal pure returns (
            uint256 tickOffset,
            uint256 wordIndex,
            uint256 setIndex
        )
    {
        unchecked {
            tickOffset = uint256(int256((tick - TickMath.MIN_TICK)));
            setIndex = tickOffset >> 16;
            wordIndex = tickOffset >> 8;
            if (setIndex >= 32) revert SetIndexOverflow();
        }
    }

    function _tick (
        uint256 tickOffset
    ) internal pure returns (
        int24 tick
    ) {
        unchecked {
            tick = int24(int256(tickOffset) + TickMath.MIN_TICK);
        }
    }

    function _set(
        ICoverPoolStructs.TickMap storage tickMap,
        int24 tick
    ) internal {
        (
            uint256 blockIdx,
            uint256 wordIdx,
            uint256 compressed
        ) = _getIndices(tick);

        tickMap.words[wordIdx]   |= 1 << (compressed & 0xFF);
        tickMap.blocks[blockIdx] |= 1 << (wordIdx & 0xFF);
        tickMap.sets |= 1 << blockIdx;
    }

    function unset(
        ICoverPoolStructs.TickMap storage tickMap,
        int24 tick
    ) internal {
        (uint256 blockIdx, uint256 wordIdx, uint256 compressed) = _getIndices(tick);

        tickMap.words[wordIdx] &= ~(1 << (compressed & 0xFF));
        if (tickMap.words[wordIdx] == 0) {
            tickMap.blocks[blockIdx] &= ~(1 << (wordIdx & 0xFF));
            if (tickMap.blocks[blockIdx] == 0) {
                tickMap.sets &= ~(1 << blockIdx);
            }
        }
    }

    function nextBelow(
        ICoverPoolStructs.TickMap storage tickMap,
        int24 tick
    ) internal view returns (int24 tickBelow) {
        unchecked {
            (uint256 blockIdx, uint256 wordIdx, uint256 compressed) = _getIndices(tick);

            uint256 word = tickMap.words[wordIdx] & ((1 << (compressed & 0xFF)) - 1);
            if (word == 0) {
                uint256 block_ = tickMap.blocks[blockIdx] & ((1 << (wordIdx & 0xFF)) - 1);
                if (block_ == 0) {
                    uint256 blockMap = tickMap.sets & ((1 << blockIdx) - 1);
                    assert(blockMap != 0);

                    blockIdx = _msb(blockMap);
                    block_ = tickMap.blocks[blockIdx];
                }
                wordIdx = (blockIdx << 8) | _msb(block_);
                word = tickMap.words[wordIdx];
            }
            tickBelow = _tick((wordIdx << 8) | _msb(word));
        }
    }

    //TODO: NEXT ABOVE
    function nextAbove(
        ICoverPoolStructs.TickMap storage tickMap,
        int24 tick
    ) internal view returns (int24 tickBelow) {
        unchecked {
            (uint256 blockIdx, uint256 wordIdx, uint256 compressed) = _getIndices(tick);

            uint256 word = tickMap.words[wordIdx] & ((1 << (compressed & 0xFF)) - 1);
            if (word == 0) {
                uint256 block_ = tickMap.blocks[blockIdx] & ((1 << (wordIdx & 0xFF)) - 1);
                if (block_ == 0) {
                    uint256 blockMap = tickMap.sets & ((1 << blockIdx) - 1);
                    assert(blockMap != 0);

                    blockIdx = _msb(blockMap);
                    block_ = tickMap.blocks[blockIdx];
                }
                wordIdx = (blockIdx << 8) | _msb(block_);
                word = tickMap.words[wordIdx];
            }
            tickBelow = _tick((wordIdx << 8) | _msb(word));
        }
    }

    function _msb(uint256 x) internal pure returns (uint8 r) {
        unchecked {
            assert(x > 0);
            if (x >= 0x100000000000000000000000000000000) {
                x >>= 128;
                r += 128;
            }
            if (x >= 0x10000000000000000) {
                x >>= 64;
                r += 64;
            }
            if (x >= 0x100000000) {
                x >>= 32;
                r += 32;
            }
            if (x >= 0x10000) {
                x >>= 16;
                r += 16;
            }
            if (x >= 0x100) {
                x >>= 8;
                r += 8;
            }
            if (x >= 0x10) {
                x >>= 4;
                r += 4;
            }
            if (x >= 0x4) {
                x >>= 2;
                r += 2;
            }
            if (x >= 0x2) r += 1;
        }
    }
    
}
