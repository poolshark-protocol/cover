// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

// import './math/DyDxMath.sol';
import './math/TickMath.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './EpochMap.sol';
import './TickMap.sol';
import 'hardhat/console.sol';

library Claims {
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error UpdatePositionFirstAt(int24, int24);
    error NotEnoughPositionLiquidity();

    /////////// DEBUG FLAGS ///////////
    bool constant debugDeltas = false;

    function validate(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        ICoverPoolStructs.TickMap storage tickMap,
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
        }
        // if the position has not been crossed into at all
        else if (params.zeroForOne ? params.claim == params.upper 
                                        && EpochMap.get(tickMap, params.upper) <= cache.position.accumEpochLast
                                     : params.claim == params.lower 
                                        && EpochMap.get(tickMap, params.lower) <= cache.position.accumEpochLast
        ) {
            return (cache, true);
        }
        // early return if no update and amount burned is 0
        if (
            (
                params.zeroForOne
                    ? params.claim == params.upper && cache.priceUpper != pool.price
                    : params.claim == params.lower && cache.priceLower != pool.price /// @dev - if pool price is start tick, set claimPriceLast to next tick crossed
            ) && params.claim == state.latestTick
        ) { if (params.amount == 0 && cache.position.claimPriceLast == pool.price) return (cache, true); } /// @dev - nothing to update if pool price hasn't moved
        
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

        uint32 claimTickEpoch = EpochMap.get(tickMap, params.claim);

        // validate claim tick
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
             if (claimTickEpoch <= cache.position.accumEpochLast)
                revert WrongTickClaimedAt();
            cache.position.liquidityStashed = 0;
            //TODO: set both booleans here for claim == lower : upper
            params.zeroForOne ? cache.removeLower = false : cache.removeUpper = false;
        } else {
            // zero fill or partial fill
            uint32 claimTickNextAccumEpoch = params.zeroForOne
                ? EpochMap.get(tickMap, TickMap.previous(tickMap, params.claim))
                : EpochMap.get(tickMap, TickMap.next(tickMap, params.claim));
            ///@dev - next accumEpoch should not be greater
            if (claimTickNextAccumEpoch > cache.position.accumEpochLast) {
                //TODO: search for claim tick if necessary
                //TODO: limit search to within 10 closest words
                revert WrongTickClaimedAt();
            }
            // check if liquidity removal required
            if (params.amount > 0) {
                /// @dev - check if liquidity removal required
                cache.removeLower = params.zeroForOne
                    ? true //TODO: if claim == lower then don't clear liquidity
                    : claimTickNextAccumEpoch <= cache.position.accumEpochLast;
                cache.removeUpper = params.zeroForOne
                    ? claimTickNextAccumEpoch <= cache.position.accumEpochLast
                    : true; //TODO: if claim == lower then don't clear liquidity
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
    ) external view returns (
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
        // if (debugDeltas) {
        //     console.log('final deltas:', cache.deltas.amountOutDelta, cache.deltas.amountOutDeltaMax);
        // }   
        (cache.deltas, cache.finalDeltas) = Deltas.transfer(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
        (cache.deltas, cache.finalDeltas) = Deltas.transferMax(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
        // apply deltas and add to position
        //TODO: this shouldn't be needed; we apply what is present
        if (cache.amountInFilledMax >= cache.finalDeltas.amountInDelta)
            //TODO: take a portion based on the protocol fee
            cache.position.amountIn  += cache.finalDeltas.amountInDelta;
        cache.position.amountOut += cache.finalDeltas.amountOutDelta;
        // add remaining deltas cached back to claim tick
        // cache.deltas, cache.claimTick) = Deltas.stash(cache.deltas, cache.claimTick, 1e38, 1e38);
        if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            // burn deltas on final tick of position
            ICoverPoolStructs.Tick memory updateTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (updateTick.deltas) = Deltas.burnMax(updateTick.deltas, cache.finalDeltas);
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
    ) external view returns (
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
            cache.position.claimPriceLast  = params.zeroForOne ? TickMath.getSqrtRatioAtTick(params.upper - state.tickSpread)                                                       : TickMath.getSqrtRatioAtTick(params.lower + state.tickSpread);
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
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 2 - position start up to claim tick
        if (params.zeroForOne ? cache.priceClaim < cache.position.claimPriceLast 
                              : cache.priceClaim > cache.position.claimPriceLast) {
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
        // if(debugDeltas) {
        //     console.log('section 4 check');
        //     console.log(cache.amountInFilledMax);
        //     console.log(cache.amountOutUnfilledMax);
        // }
        return cache;
    }

    /// @dev - calculate claim from position start up to claim tick
    function section5(
        ICoverPoolStructs.UpdatePositionCache memory cache,
        ICoverPoolStructs.UpdateParams memory params
    ) external view returns (
        ICoverPoolStructs.UpdatePositionCache memory
    ) {
        // section 5 - burned liquidity past claim tick
        {
            uint160 endPrice = params.zeroForOne ? cache.priceLower
                                                 : cache.priceUpper;
            if (params.amount > 0 && cache.priceClaim != endPrice) {
                // update max deltas based on liquidity removed
                //TODO: remove maxRoundUp
                uint128 amountInOmitted; uint128 amountOutRemoved;
                (
                    amountInOmitted,
                    amountOutRemoved
                ) = Deltas.maxRoundUp(
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