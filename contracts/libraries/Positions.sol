// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./TickMath.sol";
import "./Ticks.sol";
import "../interfaces/ICoverPoolStructs.sol";
import "hardhat/console.sol";
import "./FullPrecisionMath.sol";
import "./DyDxMath.sol";

/// @notice Position management library for ranged liquidity.
library Positions
{
    error NotEnoughPositionLiquidity();
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error PositionNotUpdated();
    error InvalidLowerTick();
    error InvalidUpperTick();
    error InvalidPositionAmount();
    error InvalidPositionBoundsOrder();
    error InvalidPositionBoundsTwap();

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Positions for mapping(int24 => ICoverPoolStructs.Tick);

    function getMaxLiquidity(int24 tickSpacing) external pure returns (uint128) {
        return type(uint128).max / uint128(uint24(TickMath.MAX_TICK) / (2 * uint24(tickSpacing)));
    }

    function validate(
        ICoverPoolStructs.ValidateParams memory params
    ) external pure returns (int24, int24, int24, int24, uint128, uint256 liquidityMinted) {
        if (params.lower % int24(params.state.tickSpread) != 0) revert InvalidLowerTick();
        if (params.upper % int24(params.state.tickSpread) != 0) revert InvalidUpperTick();
        if (params.amount == 0) revert InvalidPositionAmount();
        if (params.lower >= params.upper) revert InvalidPositionBoundsOrder();
        if (params.zeroForOne) {
            if (params.lower >= params.state.latestTick) revert InvalidPositionBoundsTwap();
        } else {
            if (params.upper <= params.state.latestTick) revert InvalidPositionBoundsTwap();
        }
        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(params.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(params.upper));

        liquidityMinted = DyDxMath.getLiquidityForAmounts(
                priceLower,
                priceUpper,
                params.zeroForOne ? priceLower : priceUpper,
                params.zeroForOne ? 0 : uint256(params.amount),
                params.zeroForOne ? uint256(params.amount) : 0
        );

        // handle partial mints 
        if (params.zeroForOne) {
            if(params.upper >= params.state.latestTick) {
                params.upper = params.state.latestTick - int24(params.state.tickSpread);
                params.upperOld = params.state.latestTick;
                uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(params.upper);
                params.amount -= uint128(DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper));
                priceUpper = priceNewUpper;
            }
        }
        if (!params.zeroForOne) {
            if (params.lower <= params.state.latestTick) {
                params.lower = params.state.latestTick + int24(params.state.tickSpread);
                params.lowerOld = params.state.latestTick;
                uint256 priceNewLower = TickMath.getSqrtRatioAtTick(params.lower);
                params.amount -= uint128(DyDxMath.getDy(liquidityMinted, priceLower, priceNewLower));
                priceLower = priceNewLower;
            }
        }

        if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();

        return (params.lowerOld, params.lower, params.upper, params.upperOld, params.amount, liquidityMinted);
    }

    function add(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position))) storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.AddParams memory params
    ) external returns (uint128, ICoverPoolStructs.GlobalState memory) {
        //TODO: dilute amountDeltas when adding liquidity
        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: positions[params.owner][params.lower][params.upper],
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper)
        });
        /// call if claim != lower and liquidity being added
        /// initialize new position
        if (params.amount == 0) return (0, state);
        if (cache.position.liquidity == 0) {
            console.log('new position');
            cache.position.accumEpochLast = state.accumEpoch;
            cache.position.claimPriceLast = params.zeroForOne ? uint160(cache.priceUpper) : uint160(cache.priceLower);
        } else {
            /// validate user can still add to position
            if (params.zeroForOne ? state.latestTick < params.upper || tickNodes[params.upper].accumEpochLast > cache.position.accumEpochLast
                                  : state.latestTick > params.lower || tickNodes[params.lower].accumEpochLast > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }

        // /// validate mint amount is not over max tick liquidity
        // if (amount > 0 && uint128(amount) + cache.position.liquidity > MAX_TICK_LIQUIDITY) revert MaxTickLiquidity();

        Ticks.insert(
            ticks,
            tickNodes,
            params.lowerOld,
            params.lower,
            params.upperOld,
            params.upper,
            uint104(params.amount),
            params.zeroForOne
        );

        console.logInt(ticks[params.lower].liquidityDelta);
        console.logInt(ticks[params.upper].liquidityDelta);

        cache.position.liquidity += uint128(params.amount);
        console.log('position liquidity check:', cache.position.liquidity);


        positions[params.owner][params.lower][params.upper] = cache.position;
                console.log(positions[params.owner][params.lower][params.upper].liquidity);

        return (params.amount, state);
    }

    function remove(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position))) storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.RemoveParams memory params
    ) external returns (uint128, ICoverPoolStructs.GlobalState memory) {
        //TODO: dilute amountDeltas when adding liquidity
        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: positions[params.owner][params.lower][params.upper],
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper)
        });
        /// call if claim != lower and liquidity being added
        /// initialize new position
        if (params.amount == 0) return (0, state);
        if (params.amount > cache.position.liquidity) {
            revert NotEnoughPositionLiquidity();
        } else {
            /// validate user can remove from position
            if (params.zeroForOne ? state.latestTick < params.upper || tickNodes[params.upper].accumEpochLast > cache.position.accumEpochLast
                                  : state.latestTick > params.lower || tickNodes[params.lower].accumEpochLast > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }

        Ticks.remove(
            ticks,
            tickNodes,
            params.lower,
            params.upper,
            uint104(params.amount),
            params.zeroForOne,
            true,
            true
        );

        cache.position.amountOut += uint128(params.zeroForOne ? 
            DyDxMath.getDx(
                params.amount,
                cache.priceLower,
                cache.priceUpper
            )
            : DyDxMath.getDy(
                params.amount,
                cache.priceLower,
                cache.priceUpper
            )
        );

        console.logInt(ticks[params.lower].liquidityDelta);
        console.logInt(ticks[params.upper].liquidityDelta);

        cache.position.liquidity -= uint128(params.amount);
        positions[params.owner][params.lower][params.upper] = cache.position;

        console.log('position liquidity check:', cache.position.liquidity);
        console.log(positions[params.owner][params.lower][params.upper].liquidity);

        return (params.amount, state);
    }

    function update(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position))) storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState storage pool,
        ICoverPoolStructs.UpdateParams memory params
    ) external returns (uint128, uint128, int24, int24, ICoverPoolStructs.GlobalState memory) {
        ICoverPoolStructs.UpdatePositionCache memory cache = ICoverPoolStructs.UpdatePositionCache({
            position: positions[params.owner][params.lower][params.upper],
            feeGrowthCurrentEpoch: pool.feeGrowthCurrentEpoch,
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            claimPrice: TickMath.getSqrtRatioAtTick(params.claim),
            claimTick: tickNodes[params.claim],
            removeLower: true,
            removeUpper: true,
            amountInDelta: 0,
            amountOutDelta: 0
        });
        /// validate burn amount
        // if (params.amount < 0 && uint128(-params.amount) > cache.position.liquidity) revert NotEnoughPositionLiquidity();
        // check for no position liquidity
        // or claiming from tick w/ zero fill
        if (cache.position.liquidity == 0
        ) { 
            console.log('update return early early'); 
            return (
                    cache.position.amountIn,
                    cache.position.amountOut,
                    params.lower,
                    params.upper,
                    state
            ); 
        }

        /// validate claim param
        if (cache.position.claimPriceLast > cache.claimPrice) revert InvalidClaimTick();
        if (params.claim < params.lower || params.claim > params.upper) revert InvalidClaimTick();

        if (params.claim == (params.zeroForOne ? params.lower : params.upper)){
            // position 100% filled
            if (cache.claimTick.accumEpochLast <= cache.position.accumEpochLast) revert WrongTickClaimedAt();
            {
                /// @dev - next tick having fee growth means liquidity was cleared
                uint32 claimNextTickAccumEpoch = params.zeroForOne ? tickNodes[cache.claimTick.previousTick].accumEpochLast 
                                                                   : tickNodes[cache.claimTick.nextTick].accumEpochLast;
                if (claimNextTickAccumEpoch > cache.position.accumEpochLast) params.zeroForOne ? cache.removeLower = false 
                                                                                               : cache.removeUpper = false;
            }
            /// @dev - ignore carryover for last tick of position
            cache.amountInDelta  = ticks[params.claim].amountInDelta - int64(ticks[params.claim].amountInDeltaCarryPercent) 
                                                                    * ticks[params.claim].amountInDelta / 1e18;
            cache.amountOutDelta = ticks[params.claim].amountOutDelta - int64(ticks[params.claim].amountOutDeltaCarryPercent)
                                                                        * ticks[params.claim].amountInDelta / 1e18;
        } 
        else {
            ///@dev - next accumEpoch should not be greater
            uint32 claimNextTickAccumEpoch = params.zeroForOne ? tickNodes[cache.claimTick.previousTick].accumEpochLast 
                                                               : tickNodes[cache.claimTick.nextTick].accumEpochLast;
            console.log('claim tick:');
            console.logInt(params.claim);
            console.log(claimNextTickAccumEpoch);
            if (claimNextTickAccumEpoch > cache.position.accumEpochLast) revert WrongTickClaimedAt();
            if (params.amount < 0) {
                /// @dev - check if liquidity removal required
                cache.removeLower = params.zeroForOne ? 
                                      true
                                    : tickNodes[cache.claimTick.nextTick].accumEpochLast      <= cache.position.accumEpochLast;
                cache.removeUpper = params.zeroForOne ? 
                                      tickNodes[cache.claimTick.previousTick].accumEpochLast  <= cache.position.accumEpochLast
                                    : true;
                
            }
            if (params.claim != (params.zeroForOne ? params.upper : params.lower)) {
                /// position partial fill
                /// factor in amount deltas
                cache.amountInDelta  += ticks[params.claim].amountInDelta;
                cache.amountOutDelta += ticks[params.claim].amountOutDelta;
                /// @dev - no params.amount deltas for 0% filled
                ///TODO: handle partial fill at params.lower tick
            }
            if (params.zeroForOne ? 
                (state.latestTick < params.claim && state.latestTick >= params.lower) //TODO: not sure if second condition is possible
              : (state.latestTick > params.claim && state.latestTick <= params.upper) 
            ) {
                //handle latestTick partial fill
                uint160 latestTickPrice = TickMath.getSqrtRatioAtTick(state.latestTick);
                //TODO: stop accumulating the tick before latestTick when moving TWAP
                cache.amountInDelta += int128(int256(params.zeroForOne ? 
                        DyDxMath.getDy(
                            1, // multiplied by liquidity later
                            latestTickPrice,
                            pool.price
                        )
                        : DyDxMath.getDx(
                            1, 
                            pool.price,
                            latestTickPrice
                        )
                ));
                //TODO: implement stopPrice for pool/1
                cache.amountOutDelta += int128(int256(params.zeroForOne ? 
                    DyDxMath.getDx(
                        1, // multiplied by liquidity later
                        pool.price,
                        cache.claimPrice
                    )
                    : DyDxMath.getDy(
                        1, 
                        cache.claimPrice,
                        pool.price
                    )
                ));
                //TODO: do we need to handle minus deltas correctly depending on direction
                // modify current liquidity
                if (params.amount < 0) {
                    params.zeroForOne ? pool.liquidity -= uint128(-params.amount) 
                               : pool.liquidity -= uint128(-params.amount);
                }
            }
        }
        if (params.claim != (params.zeroForOne ? params.upper : params.lower)) {
            //TODO: switch to being the current price if necessary
            cache.position.claimPriceLast = cache.claimPrice;
            {
                // calculate what is claimable
                //TODO: should this be inside Ticks library?
                uint256 amountInClaimable  = params.zeroForOne ? 
                                                DyDxMath.getDy(
                                                    cache.position.liquidity,
                                                    cache.claimPrice,
                                                    cache.position.claimPriceLast
                                                )
                                                : DyDxMath.getDx(
                                                    cache.position.liquidity, 
                                                    cache.position.claimPriceLast,
                                                    cache.claimPrice
                                                );
                if (cache.amountInDelta > 0) {
                    amountInClaimable += FullPrecisionMath.mulDiv(
                                                                    uint128(cache.amountInDelta),
                                                                    cache.position.liquidity, 
                                                                    Q128
                                                                );
                } else if (cache.amountInDelta < 0) {
                    //TODO: handle underflow here
                    amountInClaimable -= FullPrecisionMath.mulDiv(
                                                                    uint128(-cache.amountInDelta),
                                                                    cache.position.liquidity, 
                                                                    Q128
                                                                );
                }
                //TODO: add to position
                if (amountInClaimable > 0) {
                    amountInClaimable *= (1e6 + state.swapFee) / 1e6; // factor in swap fees
                    cache.position.amountIn += uint128(amountInClaimable);
                }
            }
            {
                if (cache.amountOutDelta > 0) {
                    cache.position.amountOut += uint128(FullPrecisionMath.mulDiv(
                                                                        uint128(cache.amountOutDelta),
                                                                        cache.position.liquidity, 
                                                                        Q128
                                                                    )
                                                       );
                }
            }
        }

        // if burn or second mint
        if (params.amount < 0 || (params.amount > 0 && cache.position.liquidity > 0 && (params.zeroForOne ? params.claim < params.upper : params.claim > params.lower))) {
            Ticks.remove(
                ticks,
                tickNodes,
                params.zeroForOne ? params.lower : params.claim,
                params.zeroForOne ? params.claim : params.upper,
                uint104(uint128(-params.amount)),
                params.zeroForOne,
                cache.removeLower,
                cache.removeUpper
            );
            // they should also get params.amountOutDeltaCarry
            cache.position.amountOut += uint128(params.zeroForOne ? 
                DyDxMath.getDx(
                    uint128(-params.amount),
                    cache.priceLower,
                    cache.claimPrice
                )
                : DyDxMath.getDy(
                    uint128(-params.amount),
                    cache.claimPrice,
                    cache.priceUpper
                )
            );
            if (params.amount < 0) {
                // remove position liquidity
                cache.position.liquidity -= uint128(-params.amount);
            }
        } 
        if (params.zeroForOne ? params.claim != params.upper : params.claim != params.lower) {
            ///TODO: do tick insert here
            // handle double minting of position
            delete positions[params.owner][params.lower][params.upper];
            //TODO: handle liquidity overflow in mint call
        }

        params.zeroForOne ? positions[params.owner][params.lower][params.claim] = cache.position
                          : positions[params.owner][params.claim][params.upper] = cache.position;

        return (
            cache.position.amountIn,
            cache.position.amountOut, 
            params.zeroForOne ? params.lower : params.claim, 
            params.zeroForOne ? params.claim : params.upper,
            state
        );
    }
}
