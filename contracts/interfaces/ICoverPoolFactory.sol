// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;
import '../base/storage/CoverPoolFactoryStorage.sol';

abstract contract ICoverPoolFactory is CoverPoolFactoryStorage {

    function createCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 fee,
        int16  tickSpread,
        uint16 twapLength
    ) external virtual returns (address book);

    function getCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 fee,
        int16 tickSpread,
        uint16 twapLength
    ) external view virtual returns (address);
}
