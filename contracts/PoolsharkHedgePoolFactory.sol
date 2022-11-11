// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PoolsharkHedgePool.sol";
import "./interfaces/IPoolsharkHedgePoolFactory.sol";
import "hardhat/console.sol";

abstract contract PoolsharkHedgePoolFactory is 
    IPoolsharkHedgePoolFactory
{

    constructor(
        address _concentratedLiquidityFactory
    ) {
        owner = msg.sender;
        concentratedLiquidityFactory = _concentratedLiquidityFactory;
        // 2 bps spacing
        feeTierTickSpacing[100] = 2;
        // 20 bps spacing
        feeTierTickSpacing[500] = 20;
        // 120 bps spacing
        feeTierTickSpacing[3000] = 120;
        // 200 bps spacing
        feeTierTickSpacing[10000] = 200;
    }

    function createHedgePool(
        address fromToken,
        address destToken,
        uint256 swapFee
    ) external override returns (address book) {
        require(fromToken != destToken,
                "ERROR: Identical token addresses.");

        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        if(ERC20(token0).decimals() == 0) revert("ERROR: token0 decimals are zero.");
        if(ERC20(token1).decimals() == 0) revert("ERROR: token1 decimals are zero.");

        bytes32 key = keccak256(abi.encode(token0, token1, swapFee));

        require(poolMapping[key] == address(0), "Pool already exists");

        uint256 tickSpacing = feeTierTickSpacing[swapFee];

        require(tickSpacing != 0, "Fee tier not supported.");

        address pool = address(new PoolsharkHedgePool(abi.encode(token0, token1, swapFee, tickSpacing)));
        poolMapping[key] = book;

        poolList.push(pool);
        emit PoolCreated(token0, token1, uint24(swapFee), uint24(tickSpacing), pool);
    }

    function getHedgePool(
        address fromToken,
        address destToken,
        uint256 fee
    ) public override view returns (address) {
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        bytes32 key = keccak256(abi.encode(token0, token1, fee));

        return poolMapping[key];
    }
}