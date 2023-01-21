// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract PoolsharkHedgePoolErrors {
    error Locked();
    error InvalidToken();
    error InvalidPosition();
    error InvalidSwapFee();
    error InvalidTickSpread();
    error LiquidityOverflow();
    error Token0Missing();
    error Token1Missing();
    error InvalidTick();
    error LowerNotEvenTick();
    error UpperNotOddTick();
    error MaxTickLiquidity();
    error Overflow();
    error NotEnoughOutputLiquidity();
    error WaitUntilEnoughObservations();
}

abstract contract PoolsharkTicksErrors {
    error WrongTickOrder();
    error WrongTickLowerRange();
    error WrongTickUpperRange();
    error WrongTickLowerOrder();
    error WrongTickUpperOrder();
    error WrongTickClaimedAt();
}

abstract contract PoolsharkMiscErrors {
    // to be removed before production
    error NotImplementedYet();
}

abstract contract PoolsharkPositionErrors {
    error NotEnoughPositionLiquidity();
    error InvalidClaimTick();
}

abstract contract PoolsharkHedgePoolFactoryErrors {
    error IdenticalTokenAddresses();
    error PoolAlreadyExists();
    error FeeTierNotSupported();
}

abstract contract PoolsharkTransferErrors {
    error TransferFailed(address from, address dest);
}