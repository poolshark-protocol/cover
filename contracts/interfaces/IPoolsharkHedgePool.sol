// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import "./IPoolsharkHedgePoolStructs.sol";

/// @notice Trident Concentrated Liquidity Pool interface.
interface IPoolsharkHedgePool is  IPoolsharkHedgePoolStructs {

    // function collect(int24 lower, int24 upper) external returns (uint256 amount0fees, uint256 amount1fees);
    function mint(
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amountDesired,
        bool zeroForOne,
        bool native
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
        uint160 sqrtPriceLimitX96
        // bytes calldata data
    ) external returns (uint256 amountOut);
}
