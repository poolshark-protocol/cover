// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./utils/MathUtils.sol";
import "./base/oracle/TwapOracle.sol";

contract PoolsharkHedgePoolLibraries is
    MathUtils,
    TwapOracle
{}