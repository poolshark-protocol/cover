//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IRangeFactory.sol";
import "./RangePoolMock.sol";
import "hardhat/console.sol";

contract RangeFactoryMock is IRangeFactory {

    address mockPool;
    address owner;

    mapping(uint24 => int24) public feeTierTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor(
        address tokenA,
        address tokenB
    ) {
        owner = msg.sender;
        require(tokenA < tokenB, "wrong token order");

        feeTierTickSpacing[500] = 10;
        feeTierTickSpacing[3000] = 60;
        feeTierTickSpacing[10000] = 200;

        mockPool = address(new RangePoolMock(tokenA, tokenB, 500, 10));

        getPool[tokenA][tokenB][500] = mockPool;

        // console.log("mock pool:", mockPool);
    }



}