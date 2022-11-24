//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../interfaces/utils/ISafeCast.sol";

abstract contract SafeCast is ISafeCast {
    function toUint160(uint256 y) external pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    function toUint128(uint256 y) external pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }

    function _toUint160(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }

    function _toUint128(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }
}
