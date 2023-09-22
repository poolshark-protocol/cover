// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import '../structs/PoolsharkStructs.sol';

abstract contract ILimitPoolFactory is PoolsharkStructs {
    function createLimitPool(
        LimitPoolParams memory params
    ) external virtual returns (
        address pool,
        address poolToken
    );

    function getLimitPool(
        bytes32 poolType,
        address tokenIn,
        address tokenOut,
        uint16  swapFee
    ) external view virtual returns (
        address pool,
        address poolToken
    );
}
