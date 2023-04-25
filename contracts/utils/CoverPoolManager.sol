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
    // source name => source address
    mapping(bytes32 => address) public twapSources;
    // feeTier => tickSpread => twapLength => CoverPoolConfig
    mapping(uint16 => mapping(int16 => mapping(uint16 => CoverPoolConfig))) internal _volatilityTiers;

    uint16 public protocolFee;

    error OwnerOnly();
    error FeeToOnly();
    error FactoryAlreadySet();
    error VolatilityTierCannotBeZero();
    error VolatilityTierAlreadyEnabled();
    error VoltatilityTierTwapTooShort();
    error VolatilityTierFeeLimitExceeded();
    error TransferredToZeroAddress();
    error ProtocolFeeCeilingExceeded();
    error FeeTierNotSupported();
    error VolatilityTierNotSupported();
    error InvalidTickSpread();
    error TwapSourceNameInvalid();
    error TwapSourceAlreadyExists();
    error TwapSourceNotFound();
    error TickSpreadNotMultipleOfTickSpacing();
    error TickSpreadNotAtLeastDoubleTickSpread();

    constructor(
        bytes32 sourceName,
        address sourceAddress
    ) {
        owner = msg.sender;
        feeTo = msg.sender;
        emit OwnerTransfer(address(0), msg.sender);

        // create initial volatility tiers
        _volatilityTiers[500][20][5] = CoverPoolConfig({
           minAmountPerAuction: 1e18,
           auctionLength: 5,
           blockTime: 1000,
           syncFee: 0,
           fillFee: 0,
           minPositionWidth: 1,
           minAmountLowerPriced: true
        });
        _volatilityTiers[500][40][10] = CoverPoolConfig({
           minAmountPerAuction: 1e18,
           auctionLength: 10,
           blockTime: 1000,
           syncFee: 500,
           fillFee: 5000,
           minPositionWidth: 5,
           minAmountLowerPriced: false
        });
        emit VolatilityTierEnabled(500, 20, 5, 1e18, 5, 1000, 0, 0, 1, true);
        emit VolatilityTierEnabled(500, 40, 10, 1e18, 10, 1000, 500, 5000, 5, false);
    
        twapSources[sourceName] = sourceAddress;
        emit TwapSourceEnabled(sourceName, sourceAddress, ITwapSource(sourceAddress).factory());
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
        if(newOwner == address(0)) revert TransferredToZeroAddress();
        _transferOwner(newOwner);
    }

    function transferFeeTo(address newFeeTo) public virtual onlyFeeTo {
        if(newFeeTo == address(0)) revert TransferredToZeroAddress();
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

    function enableTwapSource(
        bytes32 sourceName,
        address sourceAddress
    ) external onlyOwner {
        if (sourceName[0] == bytes32("")) revert TwapSourceNameInvalid();
        if (twapSources[sourceName] != address(0)) revert TwapSourceAlreadyExists();
        twapSources[sourceName] = sourceAddress;
        emit TwapSourceEnabled(sourceName, sourceAddress, ITwapSource(sourceAddress).factory());
    }

    function enableVolatilityTier(
        bytes32 sourceName,
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        uint128 minAmountPerAuction,
        uint16  auctionLength,
        uint16  blockTime,
        uint16  syncFee,
        uint16  fillFee,
        int16   minPositionWidth,
        bool    minLowerPriced
    ) external onlyOwner {
        if (_volatilityTiers[feeTier][tickSpread][twapLength].auctionLength != 0) {
            revert VolatilityTierAlreadyEnabled();
        } else if (auctionLength == 0 || minAmountPerAuction == 0 || minPositionWidth <= 0) {
            revert VolatilityTierCannotBeZero();
        } else if (twapLength < 5 * blockTime / oneSecond) {
            revert VoltatilityTierTwapTooShort();
        } else if (syncFee > 10000 || fillFee > 10000) {
            revert VolatilityTierFeeLimitExceeded();
        }
        {
            // check fee tier exists
            address twapSource = twapSources[sourceName];
            if (twapSource == address(0)) revert TwapSourceNotFound();
            int24 tickSpacing = ITwapSource(twapSource).feeTierTickSpacing(feeTier);
            if (tickSpacing == 0) {
                revert FeeTierNotSupported();
            }
            // check tick multiple
            int24 tickMultiple = tickSpread / tickSpacing;
            if (tickMultiple * tickSpacing != tickSpread) {
                revert TickSpreadNotMultipleOfTickSpacing();
            } else if (tickMultiple < 2) {
                revert TickSpreadNotAtLeastDoubleTickSpread();
            }
        }
        // twapLength * blockTime should never overflow uint16
        _volatilityTiers[feeTier][tickSpread][twapLength] = CoverPoolConfig(
            minAmountPerAuction,
            auctionLength,
            blockTime,
            syncFee,
            fillFee,
            minPositionWidth,
            minLowerPriced
        );
        emit VolatilityTierEnabled(
            feeTier,
            tickSpread,
            twapLength,
            minAmountPerAuction,
            auctionLength,
            blockTime,
            syncFee,
            fillFee,
            minPositionWidth,
            minLowerPriced
        );
    }

    function setFactory(
        address factory_
    ) external onlyOwner {
        if (factory != address(0)) revert FactoryAlreadySet();
        emit FactoryChanged(factory, factory_);
        factory = factory_;
    }

    function setProtocolFee(
        uint16 protocolFee_
    ) external onlyOwner {
        if (protocolFee_ > MAX_PROTOCOL_FEE) revert ProtocolFeeCeilingExceeded();
        emit ProtocolFeeUpdated(protocolFee, protocolFee_);
        protocolFee = protocolFee_;
    }

    function collectProtocolFees(
        address[] calldata collectPools
    ) external {
        for (uint i; i < collectPools.length; i++) {
            ICoverPoolFactory(factory).collectProtocolFees(collectPools[i]);
        }
    }

    function volatilityTiers(
        uint16 feeTier,
        int16 tickSpread,
        uint16 twapLength
    ) external view returns (
        CoverPoolConfig memory config
    ) {
        config = _volatilityTiers[feeTier][tickSpread][twapLength];
    }
    
    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view {
        if (owner != msg.sender) revert OwnerOnly();
    }

    /**
     * @dev Throws if the sender is not the feeTo.
     */
    function _checkFeeTo() internal view {
        if (feeTo != msg.sender) revert FeeToOnly();
    }
}