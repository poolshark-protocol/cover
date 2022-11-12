// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

abstract contract IPoolsharkHedgePoolFactory {

    mapping(uint256 => uint256) public feeTierTickSpacing;

    address public owner;
    address public concentratedFactory;

    mapping(bytes32 => address) public poolMapping;
    address[] public poolList;

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        uint24 tickSpacing,
        address pool
    );

    function createHedgePool(
        address fromToken,
        address destToken,
        uint256 fee
    ) external virtual returns (address book);

    function getHedgePool(
        address fromToken,
        address destToken,
        uint256 fee
    ) external virtual view returns (address);
}