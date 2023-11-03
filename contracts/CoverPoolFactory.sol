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
            require(false, "InvalidTokenAddress()");
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
                require(false, "InvalidTokenDecimals()");
            }
            constants.token0Decimals = token0Decimals;
            constants.token1Decimals = token1Decimals;
        }
    
        // get twap source
        {
            (
                address _poolImpl,
                address _tokenImpl,
                address _twapSource
            ) = ICoverPoolManager(owner).poolTypes(params.poolTypeId);
            if (_poolImpl == address(0) || _twapSource == address(0))
                require(false, "PoolTypeNotFound()");
            constants.poolImpl = _poolImpl;
            constants.poolToken = _tokenImpl;
            constants.source = ITwapSource(_twapSource);
        }
        // get volatility tier config
        {
            VolatilityTier memory config = ICoverPoolManager(owner).volatilityTiers(
                params.poolTypeId,
                params.feeTier,
                params.tickSpread,
                params.twapLength
            );
            if (config.auctionLength == 0)
                require(false, "VolatilityTierNotSupported()");
            constants.minAmountPerAuction = config.minAmountPerAuction;
            constants.auctionLength = config.auctionLength;
            constants.sampleInterval = config.sampleInterval;
            constants.minPositionWidth = config.minPositionWidth;
            constants.minAmountLowerPriced = config.minAmountLowerPriced;
        }
        // record genesis time
        constants.tickSpread = params.tickSpread;
        constants.twapLength = params.twapLength;
        constants.genesisTime = uint32(block.timestamp);
        // get reference pool
        constants.inputPool  = ITwapSource(constants.source).getPool(constants.token0, constants.token1, params.feeTier);
        if (constants.inputPool == address(0))
            require (false, "InputPoolDoesNotExist()");
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

        // intialize twap source
        ICoverPool(pool).initialize();

        poolToken = constants.poolToken;

        coverPools[key] = pool;

        emit PoolCreated(
            pool,
            constants.inputPool,
            constants.token0,
            constants.token1,
            params.feeTier,
            params.tickSpread,
            params.twapLength,
            params.poolTypeId
        );
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
        ) = ICoverPoolManager(owner).poolTypes(params.poolTypeId);
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

    function syncLatestTick(
        CoverPoolParams memory params
    ) external view returns (
        int24 latestTick,
        bool inputPoolExists,
        bool twapReady
    ) {
        if (params.tokenIn == params.tokenOut || 
                params.tokenIn == address(0) || 
                params.tokenOut == address(0)) {
            return (0, false, false);
        }
        CoverImmutables memory constants;
        // set lexographical token address ordering
        constants.token0 = params.tokenIn < params.tokenOut ? params.tokenIn : params.tokenOut;
        constants.token1 = params.tokenIn < params.tokenOut ? params.tokenOut : params.tokenIn;
        // get twap source
        {
            (
                ,,
                address _twapSource
            ) = ICoverPoolManager(owner).poolTypes(params.poolTypeId);
            if (_twapSource == address(0))
                return (0, false, false);
            constants.source = ITwapSource(constants.source);
        }
        constants.inputPool  = ITwapSource(constants.source).getPool(constants.token0, constants.token1, params.feeTier);

        if (constants.inputPool == address(0))
            return (0, false, false);
        
        inputPoolExists = true;

        // generate key for pool
        bytes32 key = keccak256(abi.encode(
                                    constants.token0,
                                    constants.token1,
                                    constants.source,
                                    constants.inputPool,
                                    params.tickSpread,
                                    params.twapLength
                                ));

        // validate erc20 decimals
        {
            uint8 token0Decimals = ERC20(constants.token0).decimals();
            uint8 token1Decimals = ERC20(constants.token1).decimals();
            if (token0Decimals > 18 || token1Decimals > 18
            || token0Decimals < 6 || token1Decimals < 6) {
                return (0, true, false);
            }
        }
        // get volatility tier config
        {
            VolatilityTier memory config = ICoverPoolManager(owner).volatilityTiers(
                params.poolTypeId,
                params.feeTier,
                params.tickSpread,
                params.twapLength
            );
            if (config.auctionLength == 0)
                return (0, true, false);
            constants.sampleInterval = config.sampleInterval;
        }
        constants.tickSpread = params.tickSpread;
        constants.twapLength = params.twapLength;

        (latestTick, twapReady) = ITwapSource(constants.source).syncLatestTick(constants, coverPools[key]);
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
            constants.bounds.max
        );
        bytes memory value2 = abi.encodePacked(
            constants.minAmountPerAuction,
            constants.genesisTime,
            constants.minPositionWidth,
            constants.tickSpread,
            constants.twapLength,
            constants.auctionLength
        );
        bytes memory value3 = abi.encodePacked(
            constants.sampleInterval,
            constants.token0Decimals,
            constants.token1Decimals,
            constants.minAmountLowerPriced
        );
        return abi.encodePacked(value1, value2, value3);
    }
}
