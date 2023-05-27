// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import './ICoverPoolStructs.sol';

//TODO: combine everything into one interface
interface ICoverPool is ICoverPoolStructs {
    function mint(
        MintParams memory params
    ) external;

    function burn(
        BurnParams memory params
    ) external;

    function swap(
        SwapParams memory params
    ) external returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    );

    function quote(
        QuoteParams memory params
    ) external view returns (
        int256 inAmount,
        uint256 outAmount,
        uint256 priceAfter
    );

    function snapshot(
        SnapshotParams memory params
    ) external view returns (
        Position memory
    );

    function fees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external returns (
        uint128 token0Fees,
        uint128 token1Fees
    );
}
