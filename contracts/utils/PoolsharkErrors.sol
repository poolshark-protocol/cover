// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract PoolsharkHedgePoolErrors {
    error Locked();
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
    error NotEnoughOutputLiquidity();
    //error ZeroAddress();
}

abstract contract PoolsharkTicksErrors {
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrontTickUpperOrder();
}

abstract contract PoolsharkHedgePoolFactoryErrors {
    error IdenticalTokenAddresses();
    error PoolAlreadyExists();
    error FeeTierNotSupported();
}

abstract contract PoolsharkTransferErrors {
    error TransferFailed(address from, address dest);
}