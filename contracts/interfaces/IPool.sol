// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import './structs/PoolsharkStructs.sol';

interface IPool is PoolsharkStructs {    
    function swap(
        SwapParams memory params
    ) external returns (
        int256 amount0,
        int256 amount1
    );

    function quote(
        QuoteParams memory params
    ) external view returns (
        int256 inAmount,
        int256 outAmount,
        uint160 priceAfter
    );
}