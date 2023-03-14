// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import './ICoverPoolStructs.sol';

//TODO: combine everything into one interface
interface ICoverPool is ICoverPoolStructs {
    function collect(
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne
    ) external;

    function mint(
        MintParams calldata mintParams
    ) external;

    function burn(
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne,
        uint128 amount
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
}
