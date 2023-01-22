// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./CoverPool.sol";
import "./interfaces/ICoverPoolFactory.sol";
import "./interfaces/IRangeFactory.sol";
import "./interfaces/ICoverPoolUtils.sol";

contract CoverPoolFactory is 
    ICoverPoolFactory
{
    error IdenticalTokenAddresses();
    error InvalidTokenDecimals();
    error PoolAlreadyExists();
    error FeeTierNotSupported();
    
    constructor(
        address _concentratedFactory,
        address _libraries
    ) {
        owner = msg.sender;
        concentratedFactory = _concentratedFactory;
        libraries = _libraries;
    }

    function createCoverPool(
        address fromToken,
        address destToken,
        uint256 swapFee,
        uint24  tickSpread
    ) external override returns (address pool) {
        
        // validate token pair
        if (fromToken == destToken) {
            revert IdenticalTokenAddresses();
        }
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;
        if(ERC20(token0).decimals() == 0) revert InvalidTokenDecimals();
        if(ERC20(token1).decimals() == 0) revert InvalidTokenDecimals();

        // generate key for pool
        bytes32 key = keccak256(abi.encode(token0, token1, swapFee, tickSpread));
        if (poolMapping[key] != address(0)){
            revert PoolAlreadyExists();
        }

        // check fee tier exists and get tick spacing
        int24 tickSpacing = IRangeFactory(concentratedFactory).feeTierTickSpacing(uint24(swapFee));
        if (tickSpacing == 0) {
            revert FeeTierNotSupported();
        }

        address inputPool = getInputPool(token0, token1, swapFee);

        // console.log("factory input pool:", inputPool);

        // launch pool and save address
        pool =  address(
                    new CoverPool(
                        inputPool,
                        libraries,
                        uint24(swapFee),
                        int24(tickSpread)
                    )
                );

        poolMapping[key] = pool;
        poolList.push(pool);

        // emit event for indexers
        emit PoolCreated(token0, token1, uint24(swapFee), int24(tickSpread), pool);
    }

    function getCoverPool(
        address fromToken,
        address destToken,
        uint256 fee,
        uint24  tickSpread
    ) public override view returns (address) {

        // set lexographical token address ordering
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        // get pool address from mapping
        bytes32 key = keccak256(abi.encode(token0, token1, fee, tickSpread));

        return poolMapping[key];
    }

    function getInputPool(
        address fromToken,
        address destToken,
        uint256 swapFee
    ) internal view returns (address) {
        return IRangeFactory(concentratedFactory).getPool(fromToken, destToken, uint24(swapFee));
    }
}