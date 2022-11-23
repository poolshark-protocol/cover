//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../interfaces/IConcentratedFactory.sol";
import "./ConcentratedPoolMock.sol";
import "hardhat/console.sol";

contract ConcentratedFactoryMock is IConcentratedFactory {

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

        mockPool = address(new ConcentratedPoolMock(tokenA, tokenB, 500));

        getPool[tokenA][tokenB][500] = mockPool;

        console.log("mock pool:", mockPool);
    }



}