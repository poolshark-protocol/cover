// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "./FullPrecisionMath.sol";
import "hardhat/console.sol";

/// @notice Math library that facilitates fee handling for Trident Concentrated Liquidity Pools.
abstract contract SwapLib is
    FullPrecisionMath
{
    function handleFees(
        uint256 output,
        uint24 swapFee,
        uint256 currentLiquidity,
        uint256 totalFeeAmount,
        uint256 amountOut,
        uint256 protocolFee,
        uint256 feeGrowthGlobal
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 feeAmount = _mulDivRoundingUp(output, swapFee, 1e6);

        totalFeeAmount += feeAmount;

        amountOut += output - feeAmount;
        console.log(currentLiquidity);
        console.log(feeAmount);
        if(currentLiquidity > 0){
            feeGrowthGlobal += _mulDiv(feeAmount, 0x100000000000000000000000000000000, currentLiquidity);
        }

        return (totalFeeAmount, amountOut, protocolFee, feeGrowthGlobal);
    }
}
