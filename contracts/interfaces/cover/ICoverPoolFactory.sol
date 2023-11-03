// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import '../../base/storage/CoverPoolFactoryStorage.sol';

abstract contract ICoverPoolFactory is CoverPoolFactoryStorage {

    struct CoverPoolParams {
        address tokenIn;
        address tokenOut;
        uint16 feeTier;
        int16  tickSpread;
        uint16 twapLength;
        uint8 poolTypeId;
    }

    /**
     * @notice Creates a new CoverPool.
     * @param params The CoverPoolParams struct referenced above.
     */
    function createCoverPool(
        CoverPoolParams memory params
    ) external virtual returns (
        address pool,
        address poolToken
    );

    /**
     * @notice Fetches an existing CoverPool.
     * @param params The CoverPoolParams struct referenced above.
     */
    function getCoverPool(
        CoverPoolParams memory params
    ) external view virtual returns (
        address pool,
        address poolToken
    );
}
