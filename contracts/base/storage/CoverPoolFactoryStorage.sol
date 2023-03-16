// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract CoverPoolFactoryStorage {
    address public owner;
    address public rangePoolFactory;
    mapping(bytes32 => address) public coverPools;
}




