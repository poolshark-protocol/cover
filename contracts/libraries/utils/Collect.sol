// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../interfaces/IERC20Minimal.sol';
import '../Epochs.sol';
import '../Positions.sol';
import '../utils/SafeTransfers.sol';

library Collect {
    function mint(
        CoverPoolStructs.MintCache memory cache,
        CoverPoolStructs.CollectParams memory params
    ) internal {
        if (params.syncFees.token0 == 0 && params.syncFees.token1 == 0) return;
        // store amounts for transferOut
        uint128 amountIn;
        uint128 amountOut;

        // factor in sync fees
        if (params.zeroForOne) {
            amountIn  += params.syncFees.token1;
            amountOut += params.syncFees.token0;
        } else {
            amountIn  += params.syncFees.token0;
            amountOut += params.syncFees.token1;
        }

        /// zero out balances and transfer out
        //TODO: subtract out sync fees from transferred in amounts
        if (amountIn > 0) {
            EchidnaAssertions.assertPoolBalanceExceeded(
                (params.zeroForOne ? balance(cache.constants.token1) : balance(cache.constants.token0)),
                amountIn
            );
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token1 : cache.constants.token0, amountIn);
        } 
        if (amountOut > 0) {
            EchidnaAssertions.assertPoolBalanceExceeded(
                (params.zeroForOne ? balance(cache.constants.token0) : balance(cache.constants.token1)),
                amountOut
            );
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token0 : cache.constants.token1, amountOut);
        }
    }

    function balance(
        address token
    ) private view returns (uint256) {
        (
            bool success,
            bytes memory data
        ) = token.staticcall(
                                    abi.encodeWithSelector(
                                        IERC20Minimal.balanceOf.selector,
                                        address(this)
                                    )
                                );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function burn(
        CoverPoolStructs.BurnCache memory cache,
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        CoverPoolStructs.CollectParams memory params
    ) internal {
        params.zeroForOne ? params.upper = params.claim : params.lower = params.claim;

        // store amounts for transferOut
        uint128 amountIn  = positions[params.positionId].amountIn;
        uint128 amountOut = positions[params.positionId].amountOut;

        // factor in sync fees
        if (params.zeroForOne) {
            amountIn  += params.syncFees.token1;
            amountOut += params.syncFees.token0;
        } else {
            amountIn  += params.syncFees.token0;
            amountOut += params.syncFees.token1;
        }

        /// zero out balances and transfer out
        if (amountIn > 0) {
            EchidnaAssertions.assertPoolBalanceExceeded(
                (params.zeroForOne ? balance(cache.constants.token1) : balance(cache.constants.token0)),
                amountIn
            );
            positions[params.positionId].amountIn = 0;
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token1 : cache.constants.token0, amountIn);
        } 
        if (amountOut > 0) {
            EchidnaAssertions.assertPoolBalanceExceeded(
                (params.zeroForOne ? balance(cache.constants.token0) : balance(cache.constants.token1)),
                amountOut
            );
            positions[params.positionId].amountOut = 0;
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token0 : cache.constants.token1, amountOut);
        }
    }
}
