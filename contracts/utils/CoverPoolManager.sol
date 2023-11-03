// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import '../libraries/utils/SafeCast.sol';
import '../interfaces/cover/ICoverPool.sol';
import '../interfaces/cover/ICoverPoolFactory.sol';
import '../interfaces/cover/ICoverPoolManager.sol';
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
    // poolType => impl address
    bytes32[] _poolTypeNames;
    mapping(uint256 => address) internal _poolTypes;
    mapping(uint256 => address) internal _poolTokens;
    mapping(uint256 => address) internal _twapSources;
    // sourceName => feeTier => tickSpread => twapLength => VolatilityTier
    mapping(uint256 => mapping(uint16 => mapping(int16 => mapping(uint16 => VolatilityTier)))) internal _volatilityTiers;

    using SafeCast for uint256;

    constructor() {
        owner = msg.sender;
        feeTo = msg.sender;
        emit OwnerTransfer(address(0), msg.sender);
        emit FeeToTransfer(address(0), msg.sender);
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
        emit FeeToTransfer(oldFeeTo, newFeeTo);
    }

    function enablePoolType(
        address poolImpl_,
        address tokenImpl_,
        address twapImpl_,
        bytes32 poolTypeName_
    ) external onlyOwner {
        uint8 poolTypeId_ = _poolTypeNames.length.toUint8();
        // valid poolType name
        if(poolTypeName_ == bytes32(""))
            require (false, 'PoolTypeNameInvalid()');
        // invalid impl address
        if(poolImpl_ == address(0) || twapImpl_ == address(0) || tokenImpl_ == address(0))
            require (false, 'TwapSourceAddressZero()');
        // pool type already exists
        if(_twapSources[poolTypeId_] != address(0) || _poolTypes[poolTypeId_] != address(0))
            require (false, 'PoolTypeAlreadyExists()');
        _poolTypes[poolTypeId_] = poolImpl_;
        _poolTokens[poolTypeId_] = tokenImpl_;
        _twapSources[poolTypeId_] = twapImpl_;
        _poolTypeNames.push(poolTypeName_);
        emit PoolTypeEnabled(poolTypeId_, poolTypeName_, poolImpl_, twapImpl_, ITwapSource(twapImpl_).factory());
    }

    function enableVolatilityTier(
        uint8 poolTypeId,
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        VolatilityTier memory volTier
    ) external onlyOwner {
        if (_volatilityTiers[poolTypeId][feeTier][tickSpread][twapLength].auctionLength != 0) {
            require (false, 'VolatilityTierAlreadyEnabled()');
        } else if (volTier.auctionLength == 0 ||  volTier.minPositionWidth <= 0) {
            require (false, 'VolatilityTierCannotBeZero()');
        } else if (twapLength < 5 * volTier.sampleInterval / oneSecond) {
            require (false, 'VoltatilityTierTwapTooShort()');
        } else if (volTier.syncFee > 10000 || volTier.fillFee > 10000) {
            require (false, 'ProtocolFeeCeilingExceeded()');
        }
        address sourceAddress = _twapSources[poolTypeId];
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
        // twapLength * sampleInterval should never overflow uint16
        _volatilityTiers[poolTypeId][feeTier][tickSpread][twapLength] = volTier;

        emit VolatilityTierEnabled(
            poolTypeId,
            feeTier,
            tickSpread,
            twapLength,
            volTier.minAmountPerAuction,
            volTier.auctionLength,
            volTier.sampleInterval,
            volTier.syncFee,
            volTier.fillFee,
            volTier.minPositionWidth,
            volTier.minAmountLowerPriced
        );
    }

    function modifyVolatilityTierFees(
        uint8 poolTypeId,
        uint16 feeTier,
        int16 tickSpread,
        uint16 twapLength,
        uint16 syncFee,
        uint16 fillFee
    ) external onlyOwner {
        if (syncFee > 10000 || fillFee > 10000) {
            require (false, 'ProtocolFeeCeilingExceeded()');
        }
        _volatilityTiers[poolTypeId][feeTier][tickSpread][twapLength].syncFee = syncFee;
        _volatilityTiers[poolTypeId][feeTier][tickSpread][twapLength].fillFee = fillFee;
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
        uint8 poolTypeId
    ) external view returns (
        address poolImpl,
        address tokenImpl,
        address twapImpl
    ) {
        return (
            _poolTypes[poolTypeId],
            _poolTokens[poolTypeId],
            _twapSources[poolTypeId]
        );
    }

    function volatilityTiers(
        uint8 poolTypeId,
        uint16 feeTier,
        int16 tickSpread,
        uint16 twapLength
    ) external view returns (
        VolatilityTier memory config
    ) {
        config = _volatilityTiers[poolTypeId][feeTier][tickSpread][twapLength];
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