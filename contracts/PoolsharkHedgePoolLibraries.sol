// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./utils/DyDxMath.sol";
import "./utils/MathUtils.sol";
import "./utils/SwapLib.sol";
import "./base/oracle/TwapOracle.sol";

contract PoolsharkHedgePoolLibraries is
    DyDxMath,
    MathUtils,
    SwapLib,
    TwapOracle
{}