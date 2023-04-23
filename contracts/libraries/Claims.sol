// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './EpochMap.sol';
import './TickMap.sol';

library Claims {
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error UpdatePositionFirstAt(int24, int24);
    error NotEnoughPositionLiquidity();

    /////////// DEBUG FLAGS ///////////
    bool constant debugDeltas = true;

    function validate(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState memory pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // validate position liquidity
        if (params.amount > cache.position.liquidity) revert NotEnoughPositionLiquidity();
        if (cache.position.liquidity == 0) {
            cache.earlyReturn = true;
            return cache;
        }
        // if the position has not been crossed into at all
        else if (params.zeroForOne ? params.claim == params.upper 
                                        && EpochMap.get(tickMap, params.upper, constants.tickSpread) <= cache.position.accumEpochLast
                                     : params.claim == params.lower 
                                        && EpochMap.get(tickMap, params.lower, constants.tickSpread) <= cache.position.accumEpochLast
        ) {
            cache.earlyReturn = true;
            return cache;
        }
        // early return if no update and amount burned is 0
        if (
            (
                params.zeroForOne
                    ? params.claim == params.upper && cache.priceUpper != pool.price
                    : params.claim == params.lower && cache.priceLower != pool.price /// @dev - if pool price is start tick, set claimPriceLast to next tick crossed
            ) && params.claim == state.latestTick
        ) { if (params.amount == 0 && cache.position.claimPriceLast == pool.price) {
                cache.earlyReturn = true;
                return cache;
            } 
        } /// @dev - nothing to update if pool price hasn't moved
        
        // claim tick sanity checks
        else if (
            // claim tick is on a prior tick
            cache.position.claimPriceLast > 0 &&
            (params.zeroForOne
                    ? cache.position.claimPriceLast < cache.priceClaim
                    : cache.position.claimPriceLast > cache.priceClaim
            ) && params.claim != state.latestTick
        ) revert InvalidClaimTick(); /// @dev - wrong claim tick
        if (params.claim < params.lower || params.claim > params.upper) revert InvalidClaimTick();

        uint32 claimTickEpoch = EpochMap.get(tickMap, params.claim, constants.tickSpread);

        // validate claim tick
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
             if (claimTickEpoch <= cache.position.accumEpochLast)
                revert WrongTickClaimedAt();
        } else {
            // zero fill or partial fill
            uint32 claimTickNextAccumEpoch = params.zeroForOne
                ? EpochMap.get(tickMap, TickMap.previous(tickMap, params.claim, constants.tickSpread), constants.tickSpread)
                : EpochMap.get(tickMap, TickMap.next(tickMap, params.claim, constants.tickSpread), constants.tickSpread);
            ///@dev - next accumEpoch should not be greater
            if (claimTickNextAccumEpoch > cache.position.accumEpochLast) {
                //TODO: search for claim tick if necessary
                //TODO: limit search to within 10 closest words
                revert WrongTickClaimedAt();
            }
        }
        if (params.claim != params.upper && params.claim != params.lower) {
            // check accumEpochLast on claim tick
            if (claimTickEpoch <= cache.position.accumEpochLast)
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
            /// @dev - user cannot add liquidity if auction is active; checked for in Positions.validate()
        }
        return cache;
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

            bool transferDeltas = (cache.position.claimPriceLast == 0
                               && (params.claim != (params.zeroForOne ? params.upper : params.lower)))
                               || (params.zeroForOne ? cache.position.claimPriceLast > cache.priceClaim
                                                     : cache.position.claimPriceLast < cache.priceClaim && cache.position.claimPriceLast != 0);
            if (transferDeltas) {
                (cache.claimTick, cache.deltas) = Deltas.unstash(cache.claimTick, cache.deltas);
            }
            // if (debugDeltas) {
            //     console.log('initial deltas:', cache.deltas.amountOutDelta, cache.deltas.amountOutDeltaMax);
            // }

        } /// @dev - deltas transfer from claim tick are replaced after applying changes
        return cache;
    }

    function applyDeltas(
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        uint256 percentInDelta; uint256 percentOutDelta;
        if(cache.deltas.amountInDeltaMax > 0) { //TODO: if this is zero for some reason we can just give 100% of amountInDelta
            percentInDelta = uint256(cache.amountInFilledMax) * 1e38 / uint256(cache.deltas.amountInDeltaMax);
            percentInDelta = percentInDelta > 1e38 ? 1e38 : percentInDelta;
            if (cache.deltas.amountOutDeltaMax > 0) {
                percentOutDelta = uint256(cache.amountOutUnfilledMax) * 1e38 / uint256(cache.deltas.amountOutDeltaMax);
                percentOutDelta = percentOutDelta > 1e38 ? 1e38 : percentOutDelta;
            }
        }
        // if (debugDeltas) {
        //     console.log('final deltas:', cache.deltas.amountInDelta, cache.deltas.amountInDeltaMax);
        //     console.log(cache.deltas.amountOutDelta, cache.deltas.amountOutDeltaMax);
        // }  
        (cache.deltas, cache.finalDeltas) = Deltas.transfer(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
        (cache.deltas, cache.finalDeltas) = Deltas.transferMax(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);

        // apply deltas and add to position
        //TODO: this shouldn't be needed; we apply what is present
        // if (cache.amountInFilledMax >= cache.finalDeltas.amountInDelta)
            //TODO: take a portion based on the protocol fee
        uint128 fillFeeAmount = cache.finalDeltas.amountInDelta * constants.fillFee / 1e6;
        if (params.zeroForOne) {
            state.protocolFees.token1 += fillFeeAmount;
        } else {
            state.protocolFees.token0 += fillFeeAmount;
        }
        cache.finalDeltas.amountInDelta -= fillFeeAmount;
        cache.position.amountIn  += cache.finalDeltas.amountInDelta;
        cache.position.amountOut += cache.finalDeltas.amountOutDelta;
        // console.log('position amounts:', cache.position.amountIn, cache.position.amountOut);
        if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            // burn deltas on final tick of position
            //  = ticks[params.zeroForOne ? params.lower : params.upper];
            // console.log('burning deltas:', cache.finalDeltas.amountOutDeltaMax);
            cache.finalTick = Deltas.burnMaxMinus(cache.finalTick, cache.finalDeltas);
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
        ICoverPoolStructs.Immutables memory constants
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // delta check complete - update CPL for new position
        if(cache.position.claimPriceLast == 0) {
            cache.position.claimPriceLast = (params.zeroForOne ? cache.priceUpper 
                                                               : cache.priceLower);
        } else if (params.zeroForOne ? (cache.position.claimPriceLast != cache.priceUpper
                                        && cache.position.claimPriceLast > cache.priceClaim)
                                     : (cache.position.claimPriceLast != cache.priceLower
                                        && cache.position.claimPriceLast < cache.priceClaim))
        {
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
            cache.position.claimPriceLast  = params.zeroForOne ? TickMath.getSqrtRatioAtTick(params.upper - constants.tickSpread)
                                                               : TickMath.getSqrtRatioAtTick(params.lower + constants.tickSpread);
        }
        // if(debugDeltas) {
        //     console.log('section 1 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section2(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 2 - position start up to claim tick
        // console.log(cache.position.claimPriceLast);
        // console.log(cache.priceClaim);
        if (params.zeroForOne ? cache.priceClaim < cache.position.claimPriceLast 
                              : cache.priceClaim > cache.position.claimPriceLast) {
            // calculate if we at least cover one full tick
            uint128 amountInFilledMax; uint128 amountOutUnfilledMax;
            (
                amountInFilledMax,
                amountOutUnfilledMax
            ) = Deltas.maxRoundUp(
                cache.position.liquidity,
                cache.position.claimPriceLast,
                cache.priceClaim,
                params.zeroForOne
            );
            cache.amountInFilledMax += amountInFilledMax;
            cache.amountOutUnfilledMax += amountOutUnfilledMax;
        }
        // if(debugDeltas) {
        //     console.log('section 2 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache;
    }

    /// @dev - calculate claim from current auction unfilled section
    function section3(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.PoolState memory pool
    ) external pure returns (
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
            uint128 amountInOmitted = uint128(
                params.zeroForOne
                    ? DyDxMath.getDy(params.amount, pool.price, cache.priceClaim, false)
                    : DyDxMath.getDx(params.amount, cache.priceClaim, pool.price, false)
            );
            // add to position
            cache.position.amountOut += amountOutRemoved;
            // modify max deltas to be burned
            cache.finalDeltas.amountInDeltaMax  += amountInOmitted;
            cache.finalDeltas.amountOutDeltaMax += amountOutRemoved;
        }
        // if(debugDeltas) {
        //     console.log('section 3 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section4(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.PoolState memory pool
    ) external pure returns (
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
            pool.amountInDelta -= uint128(poolAmountInDeltaChange); //CHANGE POOL TO MEMORY
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
                pool = Deltas.burnMaxPool(pool, cache, params);
        }
        // modify claim price for section 5
        cache.priceClaim = cache.priceSpread;
        // save pool changes to cache
        cache.pool = pool;
        // if(debugDeltas) {
        //     console.log('section 4 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache; //RETURN POOL IN MEMORY
    }

    /// @dev - calculate claim from position start up to claim tick
    function section5(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external pure returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 5 - burned liquidity past claim tick
        {
            // console.log('price claim check:', cache.priceClaim);
            uint160 endPrice = params.zeroForOne ? cache.priceLower
                                                 : cache.priceUpper;
            if (params.amount > 0 && cache.priceClaim != endPrice) {
                // update max deltas based on liquidity removed
                //TODO: remove maxRoundUp
                uint128 amountInOmitted; uint128 amountOutRemoved;
                (
                    amountInOmitted,
                    amountOutRemoved
                ) = Deltas.max(
                    params.amount,
                    cache.priceClaim,
                    endPrice,
                    params.zeroForOne
                );
                cache.position.amountOut += amountOutRemoved;
                /// @auditor - we don't add to cache.amountInFilledMax and cache.amountOutUnfilledMax 
                ///            since this section of the curve is not reflected in the deltas
                if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
                    cache.finalDeltas.amountInDeltaMax += amountInOmitted;
                    cache.finalDeltas.amountOutDeltaMax += amountOutRemoved;
                }      
            }
        }
        // if(debugDeltas) {
        //     console.log('section 5 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache;
    }
}