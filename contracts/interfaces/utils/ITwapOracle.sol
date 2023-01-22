// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "../IRangePool.sol";

interface ITwapOracle {
    function initializePoolObservations(
        IRangePool pool
    ) external returns (uint8 initializable, int24 startingTick);

    function calculateAverageTick(
        IRangePool pool
    ) external view returns (int24 averageTick);

    function isPoolObservationsEnough(
        IRangePool pool
    ) external view returns (bool);
}

