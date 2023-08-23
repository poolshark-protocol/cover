// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './CoverPool.sol';
import './external/solady/LibClone.sol';
import './interfaces/ICoverPoolStructs.sol';
import './interfaces/ICoverPoolFactory.sol';
import './base/events/CoverPoolFactoryEvents.sol';
import './base/structs/CoverPoolManagerStructs.sol';
import './utils/CoverPoolErrors.sol';
import 'hardhat/console.sol';

contract CoverPoolFactory is 
    ICoverPoolFactory,
    CoverPoolFactoryEvents,
    CoverPoolFactoryErrors,
    ICoverPoolStructs
{
    using LibClone for address;

    address immutable public owner;

    constructor(
        address _owner
    ) {
        owner = _owner;
    }

    function createCoverPool(
        CoverPoolParams memory params
    ) external override returns (address pool) {
        // validate token pair
        if (params.tokenIn == params.tokenOut || params.tokenIn == address(0) || params.tokenOut == address(0)) {
            revert InvalidTokenAddress();
        }
        Immutables memory constants;
        constants.owner = owner;
        // sort tokens by address
        constants.token0 = params.tokenIn < params.tokenOut ? params.tokenIn : params.tokenOut;
        constants.token1 = params.tokenIn < params.tokenOut ? params.tokenOut : params.tokenIn;

        // validate erc20 decimals
        {
            uint8 token0Decimals = ERC20(constants.token0).decimals();
            uint8 token1Decimals = ERC20(constants.token1).decimals();
            if (token0Decimals > 18 || token1Decimals > 18
            || token0Decimals < 6 || token1Decimals < 6) {
                revert InvalidTokenDecimals();
            }
            constants.token0Decimals = token0Decimals;
            constants.token1Decimals = token1Decimals;
        }
    
        // get twap source
        {
            (
                address poolImpl,
                address twapSource
            ) = ICoverPoolManager(owner).implementations(params.implName);
            if (poolImpl == address(0) || twapSource == address(0)) revert ImplNotFound();
            constants.poolImpl = poolImpl;
            constants.source = ITwapSource(twapSource);
        }
        // get volatility tier config
        {
            VolatilityTier memory config = ICoverPoolManager(owner).volatilityTiers(
                params.implName,
                params.feeTier,
                params.tickSpread,
                params.twapLength
            );
            if (config.auctionLength == 0) revert VolatilityTierNotSupported();
            constants.minAmountPerAuction = config.minAmountPerAuction;
            constants.auctionLength = config.auctionLength;
            constants.blockTime = config.blockTime;
            constants.minPositionWidth = config.minPositionWidth;
            constants.minAmountLowerPriced = config.minAmountLowerPriced;
        }
        // record genesis time
        constants.tickSpread = params.tickSpread;
        constants.twapLength = params.twapLength;
        constants.genesisTime   = uint32(block.timestamp);
        // get reference pool
        constants.inputPool  = ITwapSource(constants.source).getPool(constants.token0, constants.token1, params.feeTier);

        // generate key for pool
        bytes32 key = keccak256(abi.encode(
                                    constants.token0,
                                    constants.token1,
                                    constants.source,
                                    constants.inputPool,
                                    constants.tickSpread,
                                    constants.twapLength
                                ));
        if (coverPools[key] != address(0)) {
            revert PoolAlreadyExists();
        }
        console.log('about to grab price bounds', constants.poolImpl);
        (
            constants.bounds.min,
            constants.bounds.max
        ) = ICoverPool(constants.poolImpl).priceBounds(constants.tickSpread);

        // launch pool and save address
        pool = constants.poolImpl.cloneDeterministic({
            salt: key,
            data: encodeConstants(constants)
        });

        coverPools[key] = pool;

        emit PoolCreated(
            pool,
            address(constants.source),
            constants.inputPool,
            constants.token0,
            constants.token1,
            constants.poolImpl,
            params.feeTier,
            params.tickSpread,
            params.twapLength
        );
    }

    function getCoverPool(
        bytes32 implName,
        address tokenIn,
        address tokenOut,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external view override returns (address) {
        // set lexographical token address ordering
        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        (
            ,
            address source
        ) = ICoverPoolManager(owner).implementations(implName);
        console.log('getting input pool', source);
        address inputPool  = ITwapSource(source).getPool(token0, token1, feeTier);
        console.log('input pool:', inputPool);
        // generate key for pool
        bytes32 key = keccak256(abi.encode(
                                    token0,
                                    token1,
                                    source,
                                    inputPool,
                                    tickSpread,
                                    twapLength
                                ));

        return coverPools[key];
    }

    function encodeConstants(
        Immutables memory constants
    ) private pure returns (bytes memory) {
        return abi.encodePacked(
            constants.owner,
            constants.token0,
            constants.token1,
            constants.source,
            constants.inputPool,
            constants.bounds.min,
            constants.bounds.max,
            constants.minAmountPerAuction,
            constants.genesisTime,
            constants.minPositionWidth,
            constants.tickSpread,
            constants.twapLength,
            constants.auctionLength
        );
    }
}
