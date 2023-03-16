// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;
import '../base/storage/CoverPoolFactoryStorage.sol';

abstract contract ICoverPoolFactory is CoverPoolFactoryStorage {

    function createCoverPool(
        address fromToken,
        address destToken,
        uint16 fee,
        int16 tickSpread,
        uint16 twapLength,
        uint16 auctionLength
    ) external virtual returns (address book);

    function getCoverPool(
        address fromToken,
        address destToken,
        uint16 fee,
        int16 tickSpread,
        uint16 twapLength,
        uint16 auctionLength
    ) external view virtual returns (address);

    function collectProtocolFees(
        address collectPool
    ) external virtual;
}
