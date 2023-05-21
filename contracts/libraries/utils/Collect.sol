// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '../../interfaces/ICoverPoolStructs.sol';
import '../Epochs.sol';
import '../Positions.sol';
import '../utils/SafeTransfers.sol';

library Collect {
    function mint(
        ICoverPoolStructs.MintCache memory cache,
        ICoverPoolStructs.CollectParams memory params
    ) internal {
        params.zeroForOne ? params.upper = params.claim : params.lower = params.claim;

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
        if (amountIn > 0) {
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token1 : cache.constants.token0, amountIn);
        } 
        if (amountOut > 0) {
            SafeTransfers.transferOut(params.to, params.zeroForOne ? cache.constants.token0 : cache.constants.token1, amountOut);
        }
    }
}
