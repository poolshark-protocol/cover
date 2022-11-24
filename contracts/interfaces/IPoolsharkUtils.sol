// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./utils/IDyDxMath.sol";
import "./utils/IFullPrecisionMath.sol";
import "./utils/IMathUtils.sol";
import "./utils/IRebaseLibrary.sol";
import "./utils/ISafeCast.sol";
import "./utils/ISwapLib.sol";
import "./utils/ITwapOracle.sol";
import "./utils/IUnsafeMath.sol";

interface IPoolsharkUtils is 
    IDyDxMath,
    IFullPrecisionMath,
    IMathUtils,
    IRebaseLibrary,
    ISafeCast,
    ISwapLib,
    ITwapOracle,
    IUnsafeMath
{}