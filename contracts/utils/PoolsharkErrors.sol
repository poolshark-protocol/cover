// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract PoolsharkErrors {
    /// @dev Error list to optimize around pool requirements.
    error Locked();
    error ZeroAddress();
    error InvalidToken();
    error InvalidSwapFee();
    error LiquidityOverflow();
    error Token0Missing();
    error Token1Missing();
    error InvalidTick();
    error LowerEven();
    error UpperOdd();
    error MaxTickLiquidity();
    error Overflow();
    error TransferFailed(address from, address dest);
}