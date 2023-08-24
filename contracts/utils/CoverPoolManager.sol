// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../interfaces/ICoverPool.sol';
import '../interfaces/ICoverPoolFactory.sol';
import '../interfaces/ICoverPoolManager.sol';
import '../base/events/CoverPoolManagerEvents.sol';

/**
 * @dev Defines the actions which can be executed by the factory admin.
 */
contract CoverPoolManager is ICoverPoolManager, CoverPoolManagerEvents {
    address public owner;
    address public feeTo;
    address public factory;
    uint16  public constant MAX_PROTOCOL_FEE = 1e4; /// @dev - max protocol fee of 1%
    uint16  public constant oneSecond = 1000;
    // sourceName => sourceAddress
    mapping(bytes32 => address) internal _twapSources;
    mapping(bytes32 => address) internal _poolTypes;
    // sourceName => feeTier => tickSpread => twapLength => VolatilityTier
    mapping(bytes32 => mapping(uint16 => mapping(int16 => mapping(uint16 => VolatilityTier)))) internal _volatilityTiers;

    constructor() {
        owner = msg.sender;
        feeTo = msg.sender;
        emit OwnerTransfer(address(0), msg.sender);

        // _implementations[implName] = sourceAddress;
        // _twapSources[implName] = sourceAddress;
        // emit ImplementationEnabled(implName, implAddress, sourceAddress, ITwapSource(sourceAddress).factory());

        // // create initial volatility tiers
        // _volatilityTiers[implName][500][20][5] = VolatilityTier({
        //    minAmountPerAuction: 0,
        //    auctionLength: 5,
        //    blockTime: 1000,
        //    syncFee: 0,
        //    fillFee: 0,
        //    minPositionWidth: 1,
        //    minAmountLowerPriced: true
        // });
        // _volatilityTiers[implName][500][40][10] = VolatilityTier({
        //    minAmountPerAuction: 0,
        //    auctionLength: 10,
        //    blockTime: 1000,
        //    syncFee: 500,
        //    fillFee: 5000,
        //    minPositionWidth: 5,
        //    minAmountLowerPriced: false
        // });
        // emit VolatilityTierEnabled(implAddress, 500, 20, 5, 1e18, 5, 1000, 0, 0, 1, true);
        // emit VolatilityTierEnabled(implAddress, 500, 40, 10, 1e18, 10, 1000, 500, 5000, 5, false);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyFeeTo() {
        _checkFeeTo();
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwner(address newOwner) public virtual onlyOwner {
        if(newOwner == address(0)) require (false, 'TransferredToZeroAddress()');
        _transferOwner(newOwner);
    }

    function transferFeeTo(address newFeeTo) public virtual onlyFeeTo {
        if(newFeeTo == address(0)) require (false, 'TransferredToZeroAddress()');
        _transferFeeTo(newFeeTo);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwner(address newOwner) internal virtual {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerTransfer(oldOwner, newOwner);
    }

    /**
     * @dev Transfers fee collection to a new account (`newFeeTo`).
     * Internal function without access restriction.
     */
    function _transferFeeTo(address newFeeTo) internal virtual {
        address oldFeeTo = feeTo;
        feeTo = newFeeTo;
        emit OwnerTransfer(oldFeeTo, newFeeTo);
    }

    function enablePoolType(
        bytes32 poolType,
        address implAddress,
        address sourceAddress
    ) external onlyOwner {
        if (poolType[0] == bytes32("")) require (false, 'TwapSourceNameInvalid()');
        if (implAddress == address(0) || sourceAddress == address(0)) require (false, 'TwapSourceAddressZero()');
        if (_twapSources[poolType] != address(0)) require (false, 'ImplementationAlreadyExists()');
        if (_poolTypes[poolType] != address(0)) require (false, 'ImplementationAlreadyExists()');
        _poolTypes[poolType] = implAddress;
        _twapSources[poolType] = sourceAddress;
        emit PoolTypeEnabled(poolType, implAddress, sourceAddress, ITwapSource(sourceAddress).factory());
    }

    function enableVolatilityTier(
        bytes32 implName,
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        VolatilityTier memory volTier
        // uint128 minAmountPerAuction,
        // uint16  auctionLength,
        // uint16  blockTime,
        // uint16  syncFee,
        // uint16  fillFee,
        // int16   minPositionWidth,
        // bool    minLowerPriced
    ) external onlyOwner {
        if (_volatilityTiers[implName][feeTier][tickSpread][twapLength].auctionLength != 0) {
            require (false, 'VolatilityTierAlreadyEnabled()');
        } else if (volTier.auctionLength == 0 ||  volTier.minPositionWidth <= 0) {
            require (false, 'VolatilityTierCannotBeZero()');
        } else if (twapLength < 5 * volTier.blockTime / oneSecond) {
            require (false, 'VoltatilityTierTwapTooShort()');
        } else if (volTier.syncFee > 10000 || volTier.fillFee > 10000) {
            require (false, 'ProtocolFeeCeilingExceeded()');
        }
        address sourceAddress = _twapSources[implName];
        address implAddress = _poolTypes[implName];
        {
            // check fee tier exists
            if (sourceAddress == address(0)) require (false, 'TwapSourceNotFound()');
            int24 tickSpacing = ITwapSource(sourceAddress).feeTierTickSpacing(feeTier);
            if (tickSpacing == 0) {
                require (false, 'FeeTierNotSupported()');
            }
            // check tick multiple
            int24 tickMultiple = tickSpread / tickSpacing;
            if (tickMultiple * tickSpacing != tickSpread) {
                require (false, 'TickSpreadNotMultipleOfTickSpacing()');
            } else if (tickMultiple < 2) {
                require (false, 'TickSpreadNotAtLeastDoubleTickSpread()');
            }
        }
        // twapLength * blockTime should never overflow uint16
        _volatilityTiers[implName][feeTier][tickSpread][twapLength] = volTier;

        emit VolatilityTierEnabled(
            implAddress,
            feeTier,
            tickSpread,
            twapLength,
            volTier.minAmountPerAuction,
            volTier.auctionLength,
            volTier.blockTime,
            volTier.syncFee,
            volTier.fillFee,
            volTier.minPositionWidth,
            volTier.minAmountLowerPriced
        );
    }

    function modifyVolatilityTierFees(
        bytes32 implName,
        uint16 feeTier,
        int16 tickSpread,
        uint16 twapLength,
        uint16 syncFee,
        uint16 fillFee
    ) external onlyOwner {
        if (syncFee > 10000 || fillFee > 10000) {
            require (false, 'ProtocolFeeCeilingExceeded()');
        }
        _volatilityTiers[implName][feeTier][tickSpread][twapLength].syncFee = syncFee;
        _volatilityTiers[implName][feeTier][tickSpread][twapLength].fillFee = fillFee;
    }

    function setFactory(
        address factory_
    ) external onlyOwner {
        if (factory != address(0)) require (false, 'FactoryAlreadySet()');
        emit FactoryChanged(factory, factory_);
        factory = factory_;
    }

    function collectProtocolFees(
        address[] calldata collectPools
    ) external {
        if (collectPools.length == 0) require (false, 'EmptyPoolsArray()');
        uint128[] memory token0Fees = new uint128[](collectPools.length);
        uint128[] memory token1Fees = new uint128[](collectPools.length);
        for (uint i; i < collectPools.length; i++) {
            (token0Fees[i], token1Fees[i]) = ICoverPool(collectPools[i]).fees(0,0,false);
        }
        emit ProtocolFeesCollected(collectPools, token0Fees, token1Fees);
    }

    function modifyProtocolFees(
        address[] calldata modifyPools,
        uint16[] calldata syncFees,
        uint16[] calldata fillFees,
        bool[] calldata setFees
    ) external onlyOwner {
        if (modifyPools.length == 0) require (false, 'EmptyPoolsArray()');
        if (modifyPools.length != syncFees.length
            || syncFees.length != fillFees.length
            || fillFees.length != setFees.length) {
            require (false, 'MismatchedArrayLengths()');
        }
        uint128[] memory token0Fees = new uint128[](modifyPools.length);
        uint128[] memory token1Fees = new uint128[](modifyPools.length);
        for (uint i; i < modifyPools.length; i++) {
            if (syncFees[i] > MAX_PROTOCOL_FEE) require (false, 'ProtocolFeeCeilingExceeded()');
            if (fillFees[i] > MAX_PROTOCOL_FEE) require (false, 'ProtocolFeeCeilingExceeded()');
            (
                token0Fees[i],
                token1Fees[i]
            ) =ICoverPool(modifyPools[i]).fees(
                syncFees[i],
                fillFees[i],
                setFees[i]
            );
        }
        emit ProtocolFeesModified(modifyPools, syncFees, fillFees, setFees, token0Fees, token1Fees);
    }

    function poolTypes(
        bytes32 poolType
    ) external view returns (
        address implAddress,
        address sourceAddress
    ) {
        return (_poolTypes[poolType], _twapSources[poolType]);
    }

    function volatilityTiers(
        bytes32 implName,
        uint16 feeTier,
        int16 tickSpread,
        uint16 twapLength
    ) external view returns (
        VolatilityTier memory config
    ) {
        config = _volatilityTiers[implName][feeTier][tickSpread][twapLength];
    }
    
    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view {
        if (owner != msg.sender) require (false, 'OwnerOnly()');
    }

    /**
     * @dev Throws if the sender is not the feeTo.
     */
    function _checkFeeTo() internal view {
        if (feeTo != msg.sender) require (false, 'FeeToOnly()');
    }
}