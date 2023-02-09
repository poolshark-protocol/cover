// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./ICoverPoolStructs.sol";

interface ICoverPool is  ICoverPoolStructs {

    function collect(
        int24 lower,
        int24 upper,
        int24 claim,
        bool  zeroForOne
    ) external returns (uint256 amountIn, uint256 amountOut);

    function mint(
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        int24 claim,
        uint128 amountDesired,
        bool zeroForOne
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
        uint256 amountIn,
        uint160 priceLimit
        // bytes calldata data
    ) external returns (uint256 amountOut);
}
