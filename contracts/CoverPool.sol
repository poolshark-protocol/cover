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


/// @notice Poolshark Cover Pool Implementation
contract CoverPool is
    ICoverPool,
    CoverPoolStorage,
    CoverPoolImmutables
{
    address public immutable factory;
    address public immutable original;

    event SimulateMint(bytes b);
    event SimulateMint(bytes4 b);
    event SimulateMint(bool b);

    modifier ownerOnly() {
        _onlyOwner();
        _;
    }

    modifier lock() {
        _prelock();
        _;
        _postlock();
    }

    constructor(
        address factory_
    ) {
        original = address(this);
        factory = factory_;
    }

    function mint(
        MintParams memory params
    ) external override lock {
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
        cache = MintCall.perform(
            params,
            cache,
            tickMap,
            ticks,
            params.zeroForOne ? positions0 : positions1
        );
        pool0 = cache.pool0;
        pool1 = cache.pool1;
        globalState = cache.state;
    }

    function burn(
        BurnParams memory params
    ) external override lock {
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
            params, 
            cache, 
            tickMap,
            ticks,
            params.zeroForOne ? positions0 : positions1
        );
        pool0 = cache.pool0;
        pool1 = cache.pool1;
        globalState = cache.state;
    }

    function swap(
        SwapParams memory params
    ) external override lock returns (
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
    ) external override returns (
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
    ) external override ownerOnly returns (
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

     function getResizedTicksForMint(
        MintParams memory params
    ) external returns (int24 lower, int24 upper, bool positionCreated){
        MintCache memory cache;
        {
            cache.state = globalState;
            cache.constants = immutables();
            cache.pool0 = pool0;
            cache.pool1 = pool1;
        }
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
        try MintCall.getResizedTicks(
            params,
            cache,
            tickMap,
            ticks,
            params.zeroForOne ? positions0 : positions1
        ) {
        } catch (bytes memory data) {
            emit SimulateMint(data);
            bytes4 sig;
            assembly {
                sig := mload(add(data, 0x20))
            }
            
            // SimulateMint error
            if (sig == hex"5cc1f67b") {
                (, lower, upper, positionCreated) = abi.decode(abi.encodePacked(bytes28(0), data),(bytes32,int24,int24,bool));
            }
            else {
                lower = -8388608;
                upper = -8388608;
                positionCreated = false;
            }
        }
    }

    function getResizedTicksForBurn(
        BurnParams memory params
    ) external returns (int24 lower, int24 upper, bool positionExists){
        if (params.to == address(0)) revert CollectToZeroAddress();
        BurnCache memory cache;
        {
            cache.state = globalState;
            cache.constants = immutables();
            cache.pool0 = pool0;
            cache.pool1 = pool1;
        }
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
        try BurnCall.getResizedTicks(
            params,
            cache,
            tickMap,
            ticks,
            params.zeroForOne ? positions0 : positions1
        ) {
        } catch (bytes memory data) {
            bytes4 sig;
            assembly {
                sig := mload(add(data, 0x20))
            }
            // SimulateBurn error
            if (sig == hex"97dd6e0a") {
                (, lower, upper, positionExists) = abi.decode(abi.encodePacked(bytes28(0), data),(bytes32,int24,int24,bool));
            }
             else {
                lower = -8388608;
                upper = -8388608;
                positionExists = false;
            }
        }
    }

    function getGlobalState() public view returns(
        GlobalState memory
    ) {
        return globalState;
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

    function _prelock() private {
        if (globalState.unlocked == 0) {
            globalState = Ticks.initialize(tickMap, pool0, pool1, globalState, immutables());
        }
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
    }

    function _postlock() private {
        globalState.unlocked = 1;
    }

    function _onlyOwner() private view {
        if (msg.sender != owner()) revert OwnerOnly();
    }
}
