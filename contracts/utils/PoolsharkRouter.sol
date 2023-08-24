// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.13;

import '../interfaces/ICoverPool.sol';
import '../interfaces/callbacks/ICoverPoolSwapCallback.sol';
import '../libraries/utils/SafeTransfers.sol';
import '../libraries/utils/SafeCast.sol';
import '../interfaces/structs/PoolsharkStructs.sol';
import '../external/solady/LibClone.sol';

contract PoolsharkRouter is
    ICoverPoolSwapCallback,
    ICoverPoolStructs,
    PoolsharkStructs
{
    using SafeCast for uint256;
    using SafeCast for int256;

    address public immutable limitPoolFactory;
    address public immutable coverPoolFactory;

    event RouterDeployed(
        address router,
        address limitPoolFactory,
        address coverPoolFactory
    );

    struct SwapCallbackData {
        address sender;
    }

    constructor(
        address limitPoolFactory_,
        address coverPoolFactory_
    ) {
        limitPoolFactory = limitPoolFactory_;
        coverPoolFactory = coverPoolFactory_;
        emit RouterDeployed(
            address(this),
            limitPoolFactory,
            coverPoolFactory
        );
    }

    function coverPoolSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        ICoverPoolStructs.Immutables memory constants = ICoverPool(msg.sender).immutables();

        // generate key for pool
        bytes32 key = keccak256(abi.encode(
            constants.token0,
            constants.token1,
            constants.source,
            constants.inputPool,
            constants.tickSpread,
            constants.twapLength
        ));

        // compute address
        address predictedAddress = LibClone.predictDeterministicAddress(
            constants.poolImpl,
            encodeCover(constants),
            key,
            coverPoolFactory
        );

        // revert on sender mismatch
        if (msg.sender != predictedAddress) require(false, 'InvalidCallerAddress()');

        // decode original sender
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));
        
        // transfer from swap caller
        if (amount0Delta < 0) {
            SafeTransfers.transferInto(constants.token0, _data.sender, uint256(-amount0Delta));
        } else {
            SafeTransfers.transferInto(constants.token1, _data.sender, uint256(-amount1Delta));
        }
    }

    function multiCall(
        address[] memory pools,
        SwapParams[] memory params 
    ) external {
        if (pools.length != params.length) require(false, 'InputArrayLengthsMismatch()');
        for (uint i = 0; i < pools.length;) {
            params[i].callbackData = abi.encode(SwapCallbackData({sender: msg.sender}));
            ICoverPool(pools[i]).swap(params[i]);
            unchecked {
                ++i;
            }
        }
    }

    function encodeCover(
        Immutables memory constants
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
}