// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../../libraries/math/TickMath.sol';
import '../../interfaces/ICoverPoolStructs.sol';
import '../../base/structs/CoverPoolFactoryStructs.sol';
import '../../utils/SafeTransfers.sol';

abstract contract CoverPoolImmutables is 
    SafeTransfers,
    CoverPoolFactoryStructs 
{
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    address public immutable inputPool; 
    uint160 public immutable MIN_PRICE;
    uint160 public immutable MAX_PRICE;
    uint128 public immutable minAmountPerAuction;
    uint32  public immutable genesisTime;
    int16   public immutable minPositionWidth;
    int16   public immutable tickSpread;
    uint16  public immutable twapLength;
    uint16  public immutable auctionLength;
    uint16  public immutable blockTime;
    uint16  public immutable syncFee;
    uint16  public immutable fillFee;
    uint8   internal immutable token0Decimals;
    uint8   internal immutable token1Decimals;
    bool    public immutable minAmountLowerPriced;

    constructor(
        CoverPoolParams memory params
    ) {
        // set addresses
        factory   = msg.sender;
        inputPool = params.inputPool;
        token0    = IRangePool(inputPool).token0();
        token1    = IRangePool(inputPool).token1();
        
        // set token decimals
        token0Decimals = ERC20(token0).decimals();
        token1Decimals = ERC20(token1).decimals();
        // if (token0Decimals > 18 || token1Decimals > 18
        //   || token0Decimals < 6 || token1Decimals < 6) {
        //     revert InvalidTokenDecimals();
        // }

        // set other immutables
        auctionLength = params.config.auctionLength;
        blockTime = params.config.blockTime;
        syncFee = params.config.syncFee;
        fillFee = params.config.fillFee;
        minPositionWidth = params.config.minPositionWidth;
        tickSpread    = params.tickSpread;
        twapLength    = params.twapLength;
        genesisTime   = uint32(block.timestamp);
        minAmountPerAuction = params.config.minAmountPerAuction;
        minAmountLowerPriced = params.config.minAmountLowerPriced;

        // set price boundaries
        MIN_PRICE = TickMath.getSqrtRatioAtTick(TickMath.MIN_TICK / tickSpread * tickSpread);
        MAX_PRICE = TickMath.getSqrtRatioAtTick(TickMath.MAX_TICK / tickSpread * tickSpread);
    }
}