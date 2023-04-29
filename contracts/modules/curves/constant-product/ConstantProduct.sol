// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import '../../../libraries/math/FullPrecisionMath.sol';
import './DyDxMath.sol';
import './TickMath.sol';

/// @notice Math library that facilitates ranged liquidity calculations.
contract ConstantProduct is
    DyDxMath,
    TickMath
{}