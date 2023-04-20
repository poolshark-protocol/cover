// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../interfaces/ICoverPool.sol';
import '../interfaces/IRangeFactory.sol';
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
    address public inputPoolFactory;
    uint16  public constant MAX_PROTOCOL_FEE = 1e4; /// @dev - max protocol fee of 1%
    uint16  public constant oneSecond = 1000;
    /// @dev - feeTier => tickSpread => twapLength => CoverPoolConfig
    mapping(uint16 => mapping(int16 => mapping(uint16 => CoverPoolConfig))) public volatilityTiers;
    uint16 public protocolFee;

    error OwnerOnly();
    error FeeToOnly();
    error FactoryAlreadySet();
    error VolatilityTierCannotBeZero();
    error VolatilityTierAlreadyEnabled();
    error VoltatilityTierTwapTooShort();
    error TransferredToZeroAddress();
    error ProtocolFeeCeilingExceeded();
    error FeeTierNotSupported();
    error VolatilityTierNotSupported();
    error InvalidTickSpread();
    error TickSpreadNotMultipleOfTickSpacing();
    error TickSpreadNotAtLeastDoubleTickSpread();

    constructor(address _inputPoolFactory) {
        owner = msg.sender;
        feeTo = msg.sender;
        inputPoolFactory = _inputPoolFactory;
        emit OwnerTransfer(address(0), msg.sender);

        /// @dev - 1e18 works for pairs with a stablecoin
        volatilityTiers[500][20][5] = CoverPoolConfig(1e18, 5, 1000, 1, true);
        emit VolatilityTierEnabled(500, 20, 5, 5, 1000, 1, 1e18, true);

        volatilityTiers[500][40][10] = CoverPoolConfig(1e18, 10, 1000, 5, false);
        emit VolatilityTierEnabled(500, 40, 10, 10, 1000, 5, 1e18, false);
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
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner != msg.sender) revert OwnerOnly();
    }

    /**
     * @dev Throws if the sender is not the feeTo.
     */
    function _checkFeeTo() internal view virtual {
        if (feeTo != msg.sender) revert FeeToOnly();
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

    function enableVolatilityTier(
        uint16  feeTier,
        int16   tickSpread,
        uint16  twapLength,
        uint16  auctionLength,
        uint16  blockTime,
        int16   minPositionWidth,
        uint128 minAmountPerAuction,
        bool    minLowerPriced
    ) external onlyOwner {
        if (volatilityTiers[feeTier][tickSpread][twapLength].auctionLength != 0) {
            revert VolatilityTierAlreadyEnabled();
        } else if (auctionLength == 0 || minAmountPerAuction == 0 || minPositionWidth <= 0) {
            revert VolatilityTierCannotBeZero();
        } else if (twapLength < 5 * blockTime / oneSecond) {
            revert VoltatilityTierTwapTooShort();
        }
        {
            // check fee tier exists
            int24 tickSpacing = IRangeFactory(inputPoolFactory).feeTierTickSpacing(feeTier);
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
        volatilityTiers[feeTier][tickSpread][twapLength] = CoverPoolConfig(
            minAmountPerAuction,
            auctionLength,
            blockTime,
            minPositionWidth,
            minLowerPriced
        );
        emit VolatilityTierEnabled(
            feeTier,
            tickSpread,
            twapLength,
            auctionLength,
            blockTime,
            minPositionWidth,
            minAmountPerAuction,
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
}