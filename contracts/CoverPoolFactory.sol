// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './CoverPool.sol';
import './interfaces/ICoverPoolFactory.sol';
import './interfaces/IRangeFactory.sol';
import './base/events/CoverPoolFactoryEvents.sol';
import './utils/CoverPoolErrors.sol';

contract CoverPoolFactory is 
    ICoverPoolFactory,
    CoverPoolFactoryEvents,
    CoverPoolFactoryErrors
{
    modifier onlyOwner() {
        if (owner != msg.sender) revert OwnerOnly();
        _;
    }

    constructor(
        address _owner,
        address _rangePoolFactory
    ) {
        owner = _owner;
        rangePoolFactory = _rangePoolFactory;
    }

    function createCoverPool(
        address fromToken,
        address destToken,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) external override returns (address pool) {
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        // generate key for pool
        bytes32 key = keccak256(abi.encode(token0, token1, feeTier, tickSpread, twapLength));
        if (coverPools[key] != address(0)) {
            revert PoolAlreadyExists();
        }
        // check fee tier exists
        int24 tickSpacing = IRangeFactory(rangePoolFactory).feeTierTickSpacing(feeTier);
        if (tickSpacing == 0) {
            revert FeeTierNotSupported();
        }
        // check tick multiple
        {
            int24 tickMultiple = tickSpread / tickSpacing;
            if (tickMultiple * tickSpacing != tickSpread) {
                revert TickSpreadNotMultipleOfTickSpacing();
            } else if (tickMultiple < 2) {
                revert TickSpreadNotAtLeastDoubleTickSpread();
            }
        }
        // check volatility tier exists
        uint16 auctionLength = ICoverPoolManager(owner).volatilityTiers(feeTier, tickSpread, twapLength);
        if (auctionLength == 0) {
            revert VolatilityTierNotSupported();
        }
        // get reference pool
        address inputPool = IRangeFactory(rangePoolFactory).getPool(token0, token1, feeTier);

        // launch pool and save address
        pool = address(new CoverPool(inputPool, tickSpread, twapLength, auctionLength));

        coverPools[key] = pool;

        emit PoolCreated(
            pool,
            inputPool,
            token0,
            token1,
            feeTier,
            tickSpread,
            twapLength,
            auctionLength
        );
    }

    function getCoverPool(
        address fromToken,
        address destToken,
        uint16 feeTier,
        int16  tickSpread,
        uint16 twapLength
    ) public view override returns (address) {
        // set lexographical token address ordering
        address token0 = fromToken < destToken ? fromToken : destToken;
        address token1 = fromToken < destToken ? destToken : fromToken;

        // get pool address from mapping
        bytes32 key = keccak256(abi.encode(token0, token1, feeTier, tickSpread, twapLength));

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
