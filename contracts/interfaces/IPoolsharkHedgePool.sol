// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "./IPoolsharkHedgePoolStructs.sol";

/// @notice Trident Concentrated Liquidity Pool interface.
interface IPoolsharkHedgePool is  IPoolsharkHedgePoolStructs {

    function setPrice(uint160 sqrtPrice) external;

    function collect(int24 lower, int24 upper) external returns (uint256 amount0fees, uint256 amount1fees);

    function mint(MintParams memory data) external returns (uint256 liquidityMinted);

    function burn(
        int24 lower,
        int24 upper,
        uint128 amount
    ) external returns (
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 token0Fees,
        uint256 token1Fees
    );

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
        // bytes calldata data
    ) external returns (uint256 amountOut);
}
