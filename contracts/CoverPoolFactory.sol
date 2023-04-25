// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './CoverPool.sol';
import './interfaces/ICoverPoolFactory.sol';
import './base/events/CoverPoolFactoryEvents.sol';
import './base/structs/CoverPoolFactoryStructs.sol';
import './base/structs/CoverPoolManagerStructs.sol';
import './utils/CoverPoolErrors.sol';

contract CoverPoolFactory is 
    ICoverPoolFactory,
    CoverPoolFactoryStructs,
    CoverPoolFactoryEvents,
    CoverPoolFactoryErrors
{
    modifier onlyOwner() {
        if (owner != msg.sender) revert OwnerOnly();
        _;
    }

    constructor(
        address _owner
    ) {
        owner = _owner;
    }

    function createCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external override returns (address pool) {
        CoverPoolParams memory params;
        // sort tokens by address
        params.token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        params.token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        // generate key for pool
        bytes32 key = keccak256(abi.encodePacked(sourceName, params.token0, params.token1, feeTier, tickSpread, twapLength));
        if (coverPools[key] != address(0)) {
            revert PoolAlreadyExists();
        }
        // get volatility tier config
        params.config = ICoverPoolManager(owner).volatilityTiers(feeTier, tickSpread, twapLength);
        if (params.config.auctionLength == 0) revert VolatilityTierNotSupported();
        // get twap source
        params.twapSource = ICoverPoolManager(owner).twapSources(sourceName);
        if (params.twapSource == address(0)) revert TwapSourceNotFound();
        params.tickSpread = tickSpread;
        params.twapLength = twapLength;
        // get reference pool
        params.inputPool  = ITwapSource(params.twapSource).getPool(params.token0, params.token1, feeTier);

        // launch pool and save address
        pool = address(new CoverPool(params));

        coverPools[key] = pool;

        emit PoolCreated(
            pool,
            params.twapSource,
            params.inputPool,
            params.token0,
            params.token1,
            feeTier,
            tickSpread,
            twapLength
        );
    }

    function getCoverPool(
        bytes32 sourceName,
        address tokenIn,
        address tokenOut,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) public view override returns (address) {
        // set lexographical token address ordering
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        // get pool address from mapping
        bytes32 key = keccak256(abi.encodePacked(sourceName, token0, token1, feeTier, tickSpread, twapLength));

        return coverPools[key];
    }

    function collectProtocolFees(
        address collectPool
    ) external override onlyOwner {
        uint128 token0Fees; uint128 token1Fees;
        (token0Fees, token1Fees) = ICoverPool(collectPool).collectFees();
        emit ProtocolFeeCollected(collectPool, token0Fees, token1Fees);
    }
}
