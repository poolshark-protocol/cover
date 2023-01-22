// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

abstract contract ICoverPoolFactory {

    mapping(uint256 => uint256) public feeTierTickSpacing;

    address public owner;
    address public concentratedFactory;
    address public libraries;

    mapping(bytes32 => address) public poolMapping;
    address[] public poolList;

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpread,
        address pool
    );

    function createCoverPool(
        address fromToken,
        address destToken,
        uint256 fee,
        uint24  tickSpread
    ) external virtual returns (address book);

    function getCoverPool(
        address fromToken,
        address destToken,
        uint256 fee,
        uint24  tickSpread
    ) external virtual view returns (address);
}