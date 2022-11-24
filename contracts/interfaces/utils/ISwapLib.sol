// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

interface ISwapLib {
    function handleFees(
        uint256 output,
        uint24  swapFee,
        uint256 currentLiquidity,
        uint256 totalFeeAmount,
        uint256 amountOut,
        uint256 protocolFee,
        uint256 feeGrowthGlobal
    )
    external
    view
    returns (
        uint256 totalFeeAmount_,
        uint256 amountOut_,
        uint256 protocolFee_,
        uint256 feeGrowthGlobal_
    );
}

