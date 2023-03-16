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
    )
    external
    returns (
        // bytes calldata data
        uint256 amountOut
    );

    function collectFees() external returns (
        uint128 token0Fees,
        uint128 token1Fees
    );
}
