// SPDX-License-Identifier: BSD
pragma solidity 0.8.13;

import { Clone } from "../../external/solady/Clone.sol";

contract CoverPoolImmutables is Clone {
    function owner() public pure returns (address) {
        return _getArgAddress(0);
    }

    function token0() public pure returns (address) {
        return _getArgAddress(20);
    }

    function token1() public pure returns (address) {
        return _getArgAddress(40);
    }

    function twapSource() public pure returns (address) {
        return _getArgAddress(60);
    }

    function inputPool() public pure returns (address) {
        return _getArgAddress(80);
    }

    function minPrice() public pure returns (uint160) {
        return _getArgUint160(100);
    }

    function maxPrice() public pure returns (uint160) {
        return _getArgUint160(120);
    }

    function minAmountPerAuction() public pure returns (uint128) {
        return _getArgUint128(140);
    }

    function genesisTime() public pure returns (uint32) {
        return _getArgUint32(156);
    }

    function minPositionWidth() public pure returns (int16) {
        return int16(_getArgUint16(160));
    }

    function tickSpread() public pure returns (int16) {
        return int16(_getArgUint16(162));
    }

    function twapLength() public pure returns (uint16) {
        return _getArgUint16(164);
    }

    function auctionLength() public pure returns (uint16) {
        return _getArgUint16(166);
    }

    function blockTime() public pure returns (uint16) {
        return _getArgUint16(168);
    }

    function token0Decimals() public pure returns (uint8) {
        return _getArgUint8(170);
    }

    function token1Decimals() public pure returns (uint8) {
        return _getArgUint8(171);
    }

    function minAmountLowerPriced() public pure returns (bool) {
        return _getArgUint8(172) > 0;
    }
}