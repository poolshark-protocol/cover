// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

// import './DyDxMath.sol';
import './TickMath.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';

library Claims {
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error UpdatePositionFirstAt(int24, int24);
    error NotEnoughPositionLiquidity();

    function validate(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState storage pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.UpdatePositionCache memory cache
    ) external view returns (
        ICoverPoolStructs.UpdatePositionCache memory,
        bool
    ) {
        // validate position liquidity
        if (params.amount > cache.position.liquidity) revert NotEnoughPositionLiquidity();
        if (cache.position.liquidity == 0) {
            return (cache, true);
        } else if (params.zeroForOne ? params.claim == params.upper 
                                        && tickNodes[params.upper].accumEpochLast <= cache.position.accumEpochLast
                                     : params.claim == params.lower 
                                        && tickNodes[params.lower].accumEpochLast <= cache.position.accumEpochLast
        ) {
            return (cache, true);
        }
        // early return if no update
        if (
            (
                params.zeroForOne
                    ? params.claim == params.upper && cache.priceUpper != pool.price
                    : params.claim == params.lower && cache.priceLower != pool.price /// @dev - if pool price is start tick, set claimPriceLast to next tick crossed
            ) && params.claim == state.latestTick
        ) { if (cache.position.claimPriceLast == pool.price) return (cache, true); } /// @dev - nothing to update if pool price hasn't moved
        
        // claim tick sanity checks
        else if (
            cache.position.claimPriceLast > 0 &&
            (
                params.zeroForOne
                    ? cache.position.claimPriceLast < cache.priceClaim
                    : cache.position.claimPriceLast > cache.priceClaim
            ) && params.claim != state.latestTick
        ) revert InvalidClaimTick(); /// @dev - wrong claim tick
        if (params.claim < params.lower || params.claim > params.upper) revert InvalidClaimTick();

        // validate claim tick
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
             if (cache.claimTickNode.accumEpochLast <= cache.position.accumEpochLast)
                revert WrongTickClaimedAt();
            cache.position.liquidityStashed = 0;
            params.zeroForOne ? cache.removeLower = false : cache.removeUpper = false;
        } else {
            // zero fill or partial fill
            uint32 claimTickNextAccumEpoch = params.zeroForOne
                ? tickNodes[cache.claimTickNode.previousTick].accumEpochLast
                : tickNodes[cache.claimTickNode.nextTick].accumEpochLast;
            ///@dev - next accumEpoch should not be greater
            if (claimTickNextAccumEpoch > cache.position.accumEpochLast)
                revert WrongTickClaimedAt();

            // check if liquidity removal required
            if (params.amount > 0) {
                /// @dev - check if liquidity removal required
                cache.removeLower = params.zeroForOne
                    ? true
                    : tickNodes[cache.claimTickNode.nextTick].accumEpochLast <=
                        cache.position.accumEpochLast;
                cache.removeUpper = params.zeroForOne
                    ? tickNodes[cache.claimTickNode.previousTick].accumEpochLast <=
                        cache.position.accumEpochLast
                    : true;
            }
        }
        if (params.claim != params.upper && params.claim != params.lower) {
            // check accumEpochLast on claim tick
            if (tickNodes[params.claim].accumEpochLast <= cache.position.accumEpochLast)
                revert WrongTickClaimedAt();
            // prevent position overwriting at claim tick
            if (params.zeroForOne) {
                if (positions[params.owner][params.lower][params.claim].liquidity > 0) {
                    revert UpdatePositionFirstAt(params.lower, params.claim);
                }
            } else {
                if (positions[params.owner][params.claim][params.upper].liquidity > 0) {
                    revert UpdatePositionFirstAt(params.claim, params.upper);
                }
            }
            // 100% of liquidity is stashed
            //TODO: work through cases with this
            cache.position.liquidityStashed = cache.position.liquidity;
            /// @auditor - user cannot add liquidity if auction is active; checked for in Positions.validate()
        }
        return (cache, false);
    }

    function getDeltas(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // transfer deltas into cache
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
            (cache.claimTick, cache.deltas) = Deltas.from(cache.claimTick, cache.deltas);
        } else {
            /// @dev - deltas are applied once per each tick claimed at
            /// @dev - deltas should never be applied if position is not crossed into
            // check if tick already claimed at
            bool applyDeltas = (cache.position.claimPriceLast == 0
                               && (params.claim != (params.zeroForOne ? params.upper : params.lower)))
                               || (params.zeroForOne ? cache.position.claimPriceLast > cache.priceClaim
                                                     : cache.position.claimPriceLast < cache.priceClaim && cache.position.claimPriceLast != 0);
            if (applyDeltas) {
                (cache.claimTick, cache.deltas) = Deltas.unstash(cache.claimTick, cache.deltas);
            }
        } /// @dev - deltas transfer from claim tick are replaced after applying changes
        return cache;
    }

    function applyDeltas(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        uint256 percentInDelta; uint256 percentOutDelta;
        if(cache.deltas.amountInDeltaMax > 0) {
            percentInDelta = uint256(cache.amountInFilledMax) * 1e38 / uint256(cache.deltas.amountInDeltaMax);
            if (cache.deltas.amountOutDeltaMax > 0) {
                percentOutDelta = uint256(cache.amountOutUnfilledMax) * 1e38 / uint256(cache.deltas.amountOutDeltaMax);
            }
        }
        (cache.deltas, cache.finalDeltas) = Deltas.transfer(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
        (cache.deltas, cache.finalDeltas) = Deltas.transferMax(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
        // apply deltas and add to position
        if (cache.amountInFilledMax >= cache.finalDeltas.amountInDelta)
            cache.position.amountIn  += cache.finalDeltas.amountInDelta;
        cache.position.amountOut += cache.finalDeltas.amountOutDelta;
        // add remaining deltas cached back to claim tick
        // cache.deltas, cache.claimTick) = Deltas.stash(cache.deltas, cache.claimTick, 1e38, 1e38);
        if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            // burn deltas on final tick of position
            ICoverPoolStructs.Tick memory updateTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (updateTick.deltas) = Deltas.burn(updateTick.deltas, cache.finalDeltas, true);
            ticks[params.zeroForOne ? params.lower : params.upper] = updateTick;
            //TODO: handle partial stashed and partial on tick
            if (params.claim == (params.zeroForOne ? params.upper : params.lower)) {
                (cache.deltas, cache.claimTick) = Deltas.to(cache.deltas, cache.claimTick);
            } else {
                (cache.deltas, cache.claimTick) = Deltas.stash(cache.deltas, cache.claimTick);
            }
        } else {
            (cache.deltas, cache.claimTick) = Deltas.to(cache.deltas, cache.claimTick);
        }
        return cache;
    }

    /// @dev - calculate claim portion of partially claimed previous auction
    function section1(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.GlobalState memory state
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // delta check complete - update CPL for new position
        if(cache.position.claimPriceLast == 0) {
            cache.position.claimPriceLast = (params.zeroForOne ? cache.priceUpper 
                                                               : cache.priceLower);
        } else if (cache.position.claimPriceLast != (params.zeroForOne ? cache.priceUpper 
                                                                       : cache.priceLower)
                   && cache.priceClaim > cache.priceSpread ) {
            // section 1 - complete previous auction claim
            {
                // amounts claimed on this update
                uint128 amountInFilledMax; uint128 amountOutUnfilledMax;
                (
                    amountInFilledMax,
                    amountOutUnfilledMax
                ) = Deltas.maxAuction(
                    cache.position.liquidity,
                    cache.position.claimPriceLast,
                    params.zeroForOne ? cache.priceUpper
                                      : cache.priceLower,
                    params.zeroForOne
                );
                //TODO: modify delta max on claim tick and lower : upper tick
                cache.amountInFilledMax    += amountInFilledMax;
                cache.amountOutUnfilledMax += amountOutUnfilledMax;
            }
            // move price to next tick in sequence for section 2
            cache.position.claimPriceLast  = params.zeroForOne ? TickMath.getSqrtRatioAtTick(params.upper - state.tickSpread)
                                                               : TickMath.getSqrtRatioAtTick(params.lower + state.tickSpread);
        }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section2(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.PoolState storage pool
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 2 - position start up to claim tick
        if (cache.position.claimPriceLast != cache.priceClaim) {
            // calculate if we at least cover one full tick
            uint128 amountInFilledMax; uint128 amountOutUnfilledMax;
            (
                amountInFilledMax,
                amountOutUnfilledMax
            ) = Deltas.max(
                cache.position.liquidity,
                cache.position.claimPriceLast,
                cache.priceClaim,
                params.zeroForOne
            );
            cache.amountInFilledMax += amountInFilledMax;
            cache.amountOutUnfilledMax += amountOutUnfilledMax;
            params.zeroForOne ? ticks[params.lower].deltas.amountOutDeltaMax -= amountOutUnfilledMax
                              : ticks[params.upper].deltas.amountOutDeltaMax -= amountOutUnfilledMax;
        } else if (params.zeroForOne ? cache.priceClaim > cache.position.claimPriceLast 
                                     : cache.priceClaim < cache.position.claimPriceLast) {
            /// @dev - second claim within current auction
            cache.priceClaim = pool.price;
        }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section3(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.PoolState storage pool
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 3 - current auction unfilled section
        if (params.amount > 0) {
            // remove if burn
            uint128 amountOutRemoved = uint128(
                params.zeroForOne
                    ? DyDxMath.getDx(params.amount, pool.price, cache.priceClaim, false)
                    : DyDxMath.getDy(params.amount, cache.priceClaim, pool.price, false)
            );
            cache.position.amountOut += amountOutRemoved;
            // modify max deltas
            params.zeroForOne ? ticks[params.lower].deltas.amountOutDeltaMax -= amountOutRemoved
                              : ticks[params.upper].deltas.amountOutDeltaMax -= amountOutRemoved;
            uint128 amountInOmitted = uint128(
                params.zeroForOne
                    ? DyDxMath.getDy(params.amount, pool.price, cache.priceClaim, false)
                    : DyDxMath.getDx(params.amount, cache.priceClaim, pool.price, false)
            );
            params.zeroForOne ? ticks[params.lower].deltas.amountInDeltaMax -= amountInOmitted
                              : ticks[params.upper].deltas.amountInDeltaMax -= amountInOmitted;
        }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section4(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.PoolState storage pool
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 4 - current auction filled section
        {
            // amounts claimed on this update
            uint128 amountInFilledMax; uint128 amountOutUnfilledMax;
            (
                amountInFilledMax,
                amountOutUnfilledMax
            ) = Deltas.maxAuction(
                cache.position.liquidity,
                (params.zeroForOne ? cache.position.claimPriceLast < cache.priceClaim
                                    : cache.position.claimPriceLast > cache.priceClaim) 
                                        ? cache.position.claimPriceLast 
                                        : cache.priceSpread,
                pool.price,
                params.zeroForOne
            );
            uint256 poolAmountInDeltaChange = uint256(cache.position.liquidity) * 1e38 
                                                / uint256(pool.liquidity) * uint256(pool.amountInDelta) / 1e38;   
            
            cache.position.amountIn += uint128(poolAmountInDeltaChange);
            pool.amountInDelta -= uint128(poolAmountInDeltaChange);
            cache.finalDeltas.amountInDeltaMax += amountInFilledMax;
            cache.finalDeltas.amountOutDeltaMax += amountOutUnfilledMax;
            /// @dev - record how much delta max was claimed
            if (params.amount < cache.position.liquidity) {
                (
                    amountInFilledMax,
                    amountOutUnfilledMax
                ) = Deltas.maxAuction(
                    cache.position.liquidity - params.amount,
                    (params.zeroForOne ? cache.position.claimPriceLast < cache.priceClaim
                                    : cache.position.claimPriceLast > cache.priceClaim) 
                                            ? cache.position.claimPriceLast 
                                            : cache.priceSpread,
                    pool.price,
                    params.zeroForOne
                );
                pool.amountInDeltaMaxClaimed  += amountInFilledMax;
                pool.amountOutDeltaMaxClaimed += amountOutUnfilledMax;
            }
        }
        if (params.amount > 0 /// @ dev - if removing L and second claim on same tick
            && (params.zeroForOne ? cache.position.claimPriceLast < cache.priceClaim
                                    : cache.position.claimPriceLast > cache.priceClaim)) {
                // reduce delta max claimed based on liquidity removed
                uint128 amountInMaxClaimedBefore; uint128 amountOutMaxClaimedBefore;
                (
                    amountInMaxClaimedBefore,
                    amountOutMaxClaimedBefore
                ) = Deltas.maxAuction(
                    params.amount,
                    cache.priceSpread,
                    cache.position.claimPriceLast,
                    params.zeroForOne
                );
                pool.amountInDeltaMaxClaimed  -= amountInMaxClaimedBefore;
                pool.amountOutDeltaMaxClaimed -= amountOutMaxClaimedBefore;
        }
        // modify claim price for section 5
        cache.priceClaim = cache.priceSpread;
        return cache;
    }

        /// @dev - calculate claim from position start up to claim tick
    function section5(
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 5 - burned liquidity past claim tick
        {
            if (params.amount > 0) {
                // update max deltas based on liquidity removed
                uint128 amountInOmitted; uint128 amountOutRemoved;
                (
                    amountInOmitted,
                    amountOutRemoved
                ) = Deltas.maxTest(
                    params.amount,
                    cache.priceClaim,
                    params.zeroForOne ? cache.priceLower
                                      : cache.priceUpper,
                    params.zeroForOne
                );
                cache.position.amountOut += amountOutRemoved;
                if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
                    params.zeroForOne ? ticks[params.lower].deltas.amountInDeltaMax -= amountInOmitted
                                      : ticks[params.upper].deltas.amountInDeltaMax -= amountInOmitted;
                    params.zeroForOne ? ticks[params.lower].deltas.amountOutDeltaMax -= amountOutRemoved
                                      : ticks[params.upper].deltas.amountOutDeltaMax -= amountOutRemoved;
                }      
            }
        }
        return cache;
    }
}