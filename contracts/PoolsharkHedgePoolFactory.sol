// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PoolsharkHedgePool.sol";
import "./interfaces/IPoolsharkHedgePoolFactory.sol";
import "hardhat/console.sol";
import "./interfaces/IConcentratedFactory.sol";

contract PoolsharkHedgePoolFactory is 
    IPoolsharkHedgePoolFactory
{
    error IdenticalTokenAddresses();
    error PoolAlreadyExists();
    error FeeTierNotSupported();
    
    constructor(
        address _concentratedFactory
    ) {
        owner = msg.sender;
        concentratedFactory = _concentratedFactory;
    }

    function createHedgePool(
        address fromToken,
        address destToken,
        uint256 swapFee
    ) external override returns (address book) {
        
        // validate token pair
        if (fromToken == destToken) {
            revert IdenticalTokenAddresses();
        }
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;
        if(ERC20(token0).decimals() == 0) revert("ERROR: token0 decimals are zero.");
        if(ERC20(token1).decimals() == 0) revert("ERROR: token1 decimals are zero.");

        // generate key for pool
        bytes32 key = keccak256(abi.encode(token0, token1, swapFee));
        if (poolMapping[key] != address(0)){
            revert PoolAlreadyExists();
        }

        // check fee tier exists and get tick spacing
        int24 tickSpacing = IConcentratedFactory(concentratedFactory).feeTierTickSpacing(uint24(swapFee));
        if (tickSpacing == 0) {
            revert FeeTierNotSupported();
        }
            //         address _factory,
            // address _twapSource,
            // address _token0, 
            // address _token1, 
            // uint24  _swapFee, 
            // uint24  _tickSpacing

        address inputPool = getPool(token0, token1, swapFee);

        // launch pool and save address
        address pool = address(
            new PoolsharkHedgePool(
                abi.encode(
                    address(this),
                    inputPool,
                    token0,
                    token1,
                    uint24(swapFee),
                    uint24(tickSpacing)
                )
            )
        );
        poolMapping[key] = book;
        poolList.push(pool);

        // emit event for indexers
        emit PoolCreated(token0, token1, uint24(swapFee), uint24(tickSpacing), pool);
    }

    function getHedgePool(
        address fromToken,
        address destToken,
        uint256 fee
    ) public override view returns (address) {

        // set lexographical token address ordering
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        // get pool address from mapping
        bytes32 key = keccak256(abi.encode(token0, token1, fee));

        return poolMapping[key];
    }

    function getPool(
        address fromToken,
        address destToken,
        uint256 swapFee
    ) internal view returns (address) {
        return IConcentratedFactory(concentratedFactory).getPool(fromToken, destToken, uint24(swapFee));
    }
}