// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "../IConcentratedPool.sol";

interface ITwapOracle {
    function initializePoolObservations(
        IConcentratedPool pool
    ) external returns (int24 startingTick);

    function calculateAverageTick(
        IConcentratedPool pool
    ) external view returns (int24 averageTick);

    function isPoolObservationsEnough(
        IConcentratedPool pool
    ) external view returns (bool);
}

