// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;
import '../base/storage/CoverPoolFactoryStorage.sol';

abstract contract ICoverPoolFactory is CoverPoolFactoryStorage {
    /**
     * @notice Creates a Cover Pool.
     * @param sourceName The name for the source of the pool (e.g. PSHARK-RANGE)
     * @param tokenIn The address for the first token in the pool.
     * @param tokenOut The address for the second token in the pool.
     * @param fee The fee tier for the inputPool.
     * @param tickSpread The tick spacing to be used for the Cover Pool.
     * @param twapLength The length of the TWAP in seconds to be used for liquidity unlocks.
     * @return pool The pool address for the Cover Pool.
     * @dev `tickSpread` must be a multiple of the `tickSpacing` for the selected feeTier
     */
    function createCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 fee,
        int16  tickSpread,
        uint16 twapLength
    ) external virtual returns (address pool);

    /**
     * @notice Gets a Cover Pool.
     * @param sourceName The name for the source of the pool (e.g. PSHARK-RANGE)
     * @param tokenIn The address for the first token in the pool.
     * @param tokenOut The address for the second token in the pool.
     * @param fee The fee tier for the inputPool.
     * @param tickSpread The tick spacing to be used for the Cover Pool.
     * @param twapLength The length of the TWAP in seconds to be used for liquidity unlocks.
     * @return pool The pool address for the Cover Pool. Returns address(0) if no pool found.
     * @dev `tickSpread` must be a multiple of the `tickSpacing` for the selected feeTier
     */
    function getCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 fee,
        int16 tickSpread,
        uint16 twapLength
    ) external view virtual returns (address pool);
}
