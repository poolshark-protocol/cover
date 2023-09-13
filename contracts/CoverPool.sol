// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import './interfaces/cover/ICoverPool.sol';
import './interfaces/cover/ICoverPoolManager.sol';
import './base/storage/CoverPoolStorage.sol';
import './base/storage/CoverPoolImmutables.sol';
import './interfaces/structs/PoolsharkStructs.sol';
import './utils/CoverPoolErrors.sol';
import './libraries/Epochs.sol';
import './libraries/pool/SwapCall.sol';
import './libraries/pool/QuoteCall.sol';
import './libraries/pool/MintCall.sol';
import './libraries/pool/BurnCall.sol';
import './libraries/math/ConstantProduct.sol';
import './external/solady/LibClone.sol';
import './external/openzeppelin/security/ReentrancyGuard.sol';

/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolImmutables,
    ReentrancyGuard
{
    address public immutable factory;
    address public immutable original;

    modifier ownerOnly() {
        _onlyOwner();
        _;
    }

    modifier canoncialOnly() {
        _onlyCanoncialClones();
        _;
    }

    constructor(
        address factory_
    ) {
        original = address(this);
        factory = factory_;
    }

    function mint(
        MintParams memory params
    ) external override
        nonReentrant(globalState)
        canoncialOnly
    {
        MintCache memory cache = MintCache({
            state: globalState,
            position: CoverPosition(address(0),0,0,0,0,0,0,0),
            constants: immutables(),
            syncFees: SyncFees(0,0),
            liquidityMinted: 0,
            pool0: pool0,
            pool1: pool1
        });
        (
            cache.state,
            cache.syncFees,
            cache.pool0, 
            cache.pool1
        ) = Epochs.syncLatest(
            ticks,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            cache.constants
        );
        MintCall.perform(
            params.zeroForOne ? positions0 : positions1,
            ticks,
            tickMap,
            globalState,
            pool0,
            pool1,
            params,
            cache
        );
    }

    function burn(
        BurnParams memory params
    ) external override
        nonReentrant(globalState)
        canoncialOnly
    {
        if (params.to == address(0)) revert CollectToZeroAddress();
        BurnCache memory cache = BurnCache({
            state: globalState,
            position: CoverPosition(address(0),0,0,0,0,0,0,0),
            constants: immutables(),
            syncFees: SyncFees(0,0),
            pool0: pool0,
            pool1: pool1
        });
        if (params.sync)
            (
                cache.state,
                cache.syncFees,
                cache.pool0,
                cache.pool1
            ) = Epochs.syncLatest(
                ticks,
                tickMap,
                cache.pool0,
                cache.pool1,
                cache.state,
                cache.constants
        );
        cache = BurnCall.perform(
            params.zeroForOne ? positions0 : positions1,
            ticks,
            tickMap,
            globalState,
            pool0,
            pool1,
            params,
            cache
        );
    }

    function swap(
        SwapParams memory params
    ) external override
        nonReentrant(globalState)
        canoncialOnly
    returns (
        int256,
        int256
    ) 
    {
        SwapCache memory cache;
        cache.pool0 = pool0;
        cache.pool1 = pool1;
        cache.state = globalState;
        cache.constants = immutables();
        (
            cache.state,
            cache.syncFees,
            cache.pool0,
            cache.pool1
        ) = Epochs.syncLatest(
            ticks,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            immutables()
        );

        return SwapCall.perform(
            params,
            cache,
            globalState,
            pool0,
            pool1
        );
    }

    function quote(
        QuoteParams memory params
    ) external view override returns (
        int256 inAmount,
        int256 outAmount,
        uint256 priceAfter
    ) {
        SwapCache memory cache;
        cache.pool0 = pool0;
        cache.pool1 = pool1;
        cache.state = globalState;
        cache.constants = immutables();
        (
            cache.state,
            cache.syncFees,
            cache.pool0,
            cache.pool1
        ) = Epochs.simulateSync(
            ticks,
            tickMap,
            cache.pool0,
            cache.pool1,
            cache.state,
            cache.constants
        );
        return QuoteCall.perform(params, cache);
    }

    function snapshot(
       SnapshotParams memory params 
    ) external view override returns (
        CoverPosition memory
    ) {
        return Positions.snapshot(
            params.zeroForOne ? positions0 : positions1,
            ticks,
            tickMap,
            globalState,
            params.zeroForOne ? pool0 : pool1,
            UpdateParams(
                params.owner,
                params.owner,
                params.burnPercent,
                params.positionId,
                0, 0,
                params.claim,
                params.zeroForOne
            ),
            immutables()
        );
    }

    function fees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external override
        ownerOnly
        canoncialOnly
    returns (
        uint128 token0Fees,
        uint128 token1Fees
    ) {
        if (setFees) {
            globalState.syncFee = syncFee;
            globalState.fillFee = fillFee;
        }
        token0Fees = globalState.protocolFees.token0;
        token1Fees = globalState.protocolFees.token1;
        address feeTo = ICoverPoolManager(owner()).feeTo();
        globalState.protocolFees.token0 = 0;
        globalState.protocolFees.token1 = 0;
        SafeTransfers.transferOut(feeTo, token0(), token0Fees);
        SafeTransfers.transferOut(feeTo, token1(), token1Fees);
    }

    function immutables() public view returns (
        CoverImmutables memory
    ) {
        return CoverImmutables(
            ITwapSource(twapSource()),
            PriceBounds(minPrice(), maxPrice()),
            owner(),
            token0(),
            token1(),
            original,
            inputPool(),
            minAmountPerAuction(),
            genesisTime(),
            minPositionWidth(),
            tickSpread(),
            twapLength(),
            auctionLength(),
            blockTime(),
            token0Decimals(),
            token1Decimals(),
            minAmountLowerPriced()
        );
    }

    function priceBounds(
        int16 tickSpacing
    ) external pure returns (uint160, uint160) {
        return ConstantProduct.priceBounds(tickSpacing);
    }

    function _onlyCanoncialClones() private view {
        // compute pool key
        bytes32 key = keccak256(abi.encode(
                                    token0(),
                                    token1(),
                                    twapSource(),
                                    inputPool(),
                                    tickSpread(),
                                    twapLength()
                                ));
        
        // compute canonical pool address
        address predictedAddress = LibClone.predictDeterministicAddress(
            original,
            encodeCover(immutables()),
            key,
            factory
        );
        // only allow delegateCall from canonical clones
        if (address(this) != predictedAddress) require(false, 'NoDelegateCall()');
    }

    function encodeCover(
        CoverImmutables memory constants
    ) private pure returns (bytes memory) {
        bytes memory value1 = abi.encodePacked(
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
        bytes memory value2 = abi.encodePacked(
            constants.blockTime,
            constants.token0Decimals,
            constants.token1Decimals,
            constants.minAmountLowerPriced
        );
        return abi.encodePacked(value1, value2);
    }

    function _onlyOwner() private view {
        if (msg.sender != owner()) revert OwnerOnly();
    }
}
