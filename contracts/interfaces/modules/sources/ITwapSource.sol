// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../../structs/PoolsharkStructs.sol';

interface ITwapSource {
    function initialize(
        PoolsharkStructs.CoverImmutables memory constants
    ) external returns (
        uint8 initializable,
        int24 startingTick
    );

    function calculateAverageTick(
        PoolsharkStructs.CoverImmutables memory constants,
        int24 latestTick
    ) external view returns (
        int24 averageTick
    );

    function calculateAverageTicks(
        PoolsharkStructs.CoverImmutables memory constants
    ) external view returns (
        int24[4] memory averageTicks
    );

    function syncLatestTick(
        PoolsharkStructs.CoverImmutables memory constants,
        address coverPool
    ) external view returns (
        int24 latestTick,
        bool twapReady
    );

    function getPool(
        address tokenA,
        address tokenB,
        uint16 feeTier
    ) external view returns (
        address pool
    );

    function feeTierTickSpacing(
        uint16 feeTier
    ) external view returns (
        int24 tickSpacing
    );

    function factory()
        external view returns (address);
}
