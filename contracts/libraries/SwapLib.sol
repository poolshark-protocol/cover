// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import "./FullPrecisionMath.sol";

/// @notice Math library that facilitates fee handling for Trident Concentrated Liquidity Pools.
library SwapLib {
    function handleFees(
        uint256 output,
        uint24 swapFee,
        uint256 currentLiquidity,
        uint256 totalFeeAmount,
        uint256 amountOut,
        uint256 protocolFee,
        uint256 feeGrowthGlobal
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 feeAmount = FullPrecisionMath.mulDivRoundingUp(output, swapFee, 1e6);

        totalFeeAmount += feeAmount;

        amountOut += output - feeAmount;

        feeGrowthGlobal += FullPrecisionMath.mulDiv(feeAmount, 0x100000000000000000000000000000000, currentLiquidity);

        return (totalFeeAmount, amountOut, protocolFee, feeGrowthGlobal);
    }
}
