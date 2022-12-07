// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "./FullPrecisionMath.sol";

/// @notice Math library that facilitates fee handling for Trident Concentrated Liquidity Pools.
abstract contract SwapLib is
    FullPrecisionMath
{
    function handleFees(
        uint256 output,
        uint24 swapFee,
        uint256 totalFeeAmount,
        uint256 amountOut
    )
        external
        pure
        returns (
            uint256,
            uint256
        )
    {
        amountOut += output; // @dev fee is taken on input amount

        return (totalFeeAmount, amountOut);
    }
}
