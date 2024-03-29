// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import './CoverPool.sol';
import './external/solady/LibClone.sol';
import './interfaces/structs/CoverPoolStructs.sol';
import './interfaces/cover/ICoverPoolFactory.sol';
import './base/events/CoverPoolFactoryEvents.sol';
import './utils/CoverPoolErrors.sol';

contract CoverPoolFactory is 
    ICoverPoolFactory,
    CoverPoolFactoryEvents,
    CoverPoolFactoryErrors,
    CoverPoolStructs
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
    ) public override returns (
        address pool,
        address poolToken
    ) {
        // validate token pair
        if (params.tokenIn == params.tokenOut || params.tokenIn == address(0) || params.tokenOut == address(0)) {
            revert InvalidTokenAddress();
        }
        CoverImmutables memory constants;
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
                address tokenImpl,
                address twapSource
            ) = ICoverPoolManager(owner).poolTypes(params.poolType);
            if (poolImpl == address(0) || twapSource == address(0)) revert PoolTypeNotFound();
            constants.poolImpl = poolImpl;
            constants.poolToken = tokenImpl;
            constants.source = ITwapSource(twapSource);
        }
        // get volatility tier config
        {
            VolatilityTier memory config = ICoverPoolManager(owner).volatilityTiers(
                params.poolType,
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
        bytes32 key = keccak256(
            abi.encode(
                constants.token0,
                constants.token1,
                constants.source,
                constants.inputPool,
                constants.tickSpread,
                constants.twapLength
            )
        );
        if (coverPools[key] != address(0)) {
            revert PoolAlreadyExists();
        }

        (
            constants.bounds.min,
            constants.bounds.max
        ) = ICoverPool(constants.poolImpl).priceBounds(constants.tickSpread);

        // launch pool token
        constants.poolToken = constants.poolToken.cloneDeterministic({
            salt: key,
            data: abi.encodePacked(
                constants.poolImpl
            )
        });

        // launch pool and save address
        pool = constants.poolImpl.cloneDeterministic({
            salt: key,
            data: encodeCover(constants)
        });

        poolToken = constants.poolToken;

        coverPools[key] = pool;

        emit PoolCreated(
            pool,
            constants.inputPool,
            constants.token0,
            constants.token1,
            params.poolType,
            params.feeTier,
            params.tickSpread,
            params.twapLength
        );
    }

    function createCoverPoolAndMint(
        CoverPoolParams memory params,
        ICoverPool.MintParams[] memory mintCoverParams
    ) external returns (
        address pool,
        address poolToken
    ) {
        // check if pool exists
        (
            pool,
            poolToken
        ) = getCoverPool(
            params
        );
        // create if pool doesn't exist
        if (pool == address(0)) {
            (
                pool,
                poolToken
            ) = createCoverPool(
                params
            );
        }
        // mint initial cover positions
        for (uint i = 0; i < mintCoverParams.length;) {
            ICoverPool(pool).mint(mintCoverParams[i]);
            unchecked {
                ++i;
            }
        }
    } 

    function getCoverPool(
        CoverPoolParams memory params
    ) public view override returns (
        address pool,
        address poolToken
    ) {
        // set lexographical token address ordering
        address token0 = params.tokenIn < params.tokenOut ? params.tokenIn : params.tokenOut;
        address token1 = params.tokenIn < params.tokenOut ? params.tokenOut : params.tokenIn;

        (
            address poolImpl,
            address tokenImpl,
            address source
        ) = ICoverPoolManager(owner).poolTypes(params.poolType);
        address inputPool  = ITwapSource(source).getPool(token0, token1, params.feeTier);

        // generate key for pool
        bytes32 key = keccak256(abi.encode(
                                    token0,
                                    token1,
                                    source,
                                    inputPool,
                                    params.tickSpread,
                                    params.twapLength
                                ));
        
        pool = coverPools[key];

        poolToken = LibClone.predictDeterministicAddress(
            tokenImpl,
            abi.encodePacked(
                poolImpl
            ),
            key,
            address(this)
        );
    }

    function encodeCover(
        CoverImmutables memory constants
    ) private pure returns (bytes memory) {
        bytes memory value1 = abi.encodePacked(
            constants.owner,
            constants.token0,
            constants.token1,
            constants.source,
            constants.poolToken,
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
        bytes memory value2 = abi.encodePacked(
            constants.blockTime,
            constants.token0Decimals,
            constants.token1Decimals,
            constants.minAmountLowerPriced
        );
        return abi.encodePacked(value1, value2);
    }
}
