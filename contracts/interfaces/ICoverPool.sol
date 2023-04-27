// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import './ICoverPoolStructs.sol';

//TODO: combine everything into one interface
interface ICoverPool is ICoverPoolStructs {
    function mint(
        MintParams memory mintParams
    ) external;

    function burn(
        BurnParams calldata burnParams
    ) external;

    function swap(
        address recipient,
        bool zeroForOne,
        uint128 amountIn,
        uint160 priceLimit
    ) external;

    function quote(
        bool zeroForOne,
        uint128 amountIn,
        uint160 priceLimit
    ) external view returns (
        uint256 inAmount,
        uint256 outAmount
    );

    function protocolFees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external returns (
        uint128 token0Fees,
        uint128 token1Fees
    );
}
