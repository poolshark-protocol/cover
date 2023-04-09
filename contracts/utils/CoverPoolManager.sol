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
    address public _owner;
    address private _feeTo;
    address public _factory;
    uint16  public immutable MAX_PROTOCOL_FEE = 1e4; /// @dev - max protocol fee of 1%

    /// @dev - feeTier => tickSpread => twapLength => auctionLength
    mapping(uint16 => mapping(int16 => mapping(uint16 => CoverPoolConfig))) public volatilityTiers;
    uint16 public protocolFee;

    error OwnerOnly();
    error FeeToOnly();
    error VolatilityTierInvalid();
    error VolatilityTierAlreadyEnabled();
    error TransferredToZeroAddress();
    error ProtocolFeeCeilingExceeded();

    constructor() {
        _owner = msg.sender;
        _feeTo = msg.sender;
        emit OwnerTransfer(address(0), msg.sender);

        volatilityTiers[500][20][5] = CoverPoolConfig(20, 2, 1e18);
        emit VolatilityTierEnabled(500, 20, 5, 20, 2, 1e18);

        volatilityTiers[500][40][40] = CoverPoolConfig(40, 5, 1e18);
        emit VolatilityTierEnabled(500, 40, 40, 40, 5, 1e18);
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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function feeTo() public view virtual returns (address) {
        return _feeTo;
    }

    function factory() public view virtual returns (address) {
        return _factory;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) revert OwnerOnly();
    }

    /**
     * @dev Throws if the sender is not the feeTo.
     */
    function _checkFeeTo() internal view virtual {
        if (feeTo() != msg.sender) revert FeeToOnly();
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
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnerTransfer(oldOwner, newOwner);
    }

    /**
     * @dev Transfers fee collection to a new account (`newFeeTo`).
     * Internal function without access restriction.
     */
    function _transferFeeTo(address newFeeTo) internal virtual {
        address oldFeeTo = _feeTo;
        _feeTo = newFeeTo;
        emit OwnerTransfer(oldFeeTo, newFeeTo);
    }

    function enableVolatilityTier(
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        uint16  auctionLength,
        uint128 minAuctionAmount,
        uint8   minPositionWidth
    ) external onlyOwner {
        if (volatilityTiers[feeTier][tickSpread][twapLength].auctionLength != 0) {
            revert VolatilityTierAlreadyEnabled();
        } else if (auctionLength == 0 || minAuctionAmount == 0 || minPositionWidth == 0) {
            revert VolatilityTierInvalid();
        }
        volatilityTiers[feeTier][tickSpread][twapLength] = CoverPoolConfig(auctionLength, minPositionWidth, minAuctionAmount);
        emit VolatilityTierEnabled(
            feeTier,
            tickSpread,
            twapLength,
            auctionLength,
            minPositionWidth,
            minAuctionAmount
        );
    }

    function setFactory(
        address factory_
    ) external onlyOwner {
        emit FactoryChanged(_factory, factory_);
        _factory = factory_;
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
            ICoverPoolFactory(factory()).collectProtocolFees(collectPools[i]);
        }
    }
}