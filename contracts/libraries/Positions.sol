// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import './Ticks.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './FullPrecisionMath.sol';
import './DyDxMath.sol';
import 'hardhat/console.sol';


/// @notice Position management library for ranged liquidity.
library Positions {
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error PositionNotUpdated();
    error UpdatePositionFirstAt(int24, int24);
    error InvalidLowerTick();
    error InvalidUpperTick();
    error InvalidPositionAmount();
    error InvalidPositionBoundsOrder();
    error InvalidPositionBoundsTwap();
    error NotEnoughPositionLiquidity();
    error NotImplementedYet();

    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    using Positions for mapping(int24 => ICoverPoolStructs.Tick);

    function validate(ICoverPoolStructs.ValidateParams memory params)
        external
        pure
        returns (
            int24,
            int24,
            int24,
            int24,
            uint128,
            uint256 liquidityMinted
        )
    {
        if (params.lower < TickMath.MIN_TICK) revert InvalidLowerTick();
        if (params.upper > TickMath.MAX_TICK) revert InvalidUpperTick();
        if (params.lower % int24(params.state.tickSpread) != 0) revert InvalidLowerTick();
        if (params.upper % int24(params.state.tickSpread) != 0) revert InvalidUpperTick();
        if (params.amount == 0) revert InvalidPositionAmount();
        if (params.lower >= params.upper || params.lowerOld >= params.upperOld)
            revert InvalidPositionBoundsOrder();
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
            if (params.upper >= params.state.latestTick) {
                params.upper = params.state.latestTick - int24(params.state.tickSpread);
                params.upperOld = params.state.latestTick;
                uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(params.upper);
                params.amount -= uint128(
                    DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper, false)
                );
                priceUpper = priceNewUpper;
            }
        } else {
            if (params.lower <= params.state.latestTick) {
                params.lower = params.state.latestTick + int24(params.state.tickSpread);
                params.lowerOld = params.state.latestTick;
                uint256 priceNewLower = TickMath.getSqrtRatioAtTick(params.lower);
                params.amount -= uint128(
                    DyDxMath.getDy(liquidityMinted, priceLower, priceNewLower, false)
                );
                priceLower = priceNewLower;
            }
        }

        if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();
        if (params.lower == params.upper) revert InvalidPositionBoundsTwap();

        return (
            params.lowerOld,
            params.lower,
            params.upper,
            params.upperOld,
            params.amount,
            liquidityMinted
        );
    }

    function add(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
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
            cache.position.accumEpochLast = state.accumEpoch;
        } else {
            /// safety check...might be unnecessary given the user is forced to update()
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        tickNodes[params.upper].accumEpochLast > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        tickNodes[params.lower].accumEpochLast > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }
        //TODO: if cPL is > 0, revert
        
        // add liquidity to ticks
        state = Ticks.insert(
            ticks,
            tickNodes,
            state,
            params.lowerOld,
            params.lower,
            params.upperOld,
            params.upper,
            uint128(params.amount),
            params.zeroForOne
        );

        {
            // update max deltas
            ICoverPoolStructs.Deltas memory tickDeltas = ticks[params.zeroForOne ? params.lower : params.upper].deltas;
            tickDeltas = Deltas.update(tickDeltas, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, true);
            ticks[params.zeroForOne ? params.lower : params.upper].deltas = tickDeltas;
        }

        cache.position.liquidity += uint128(params.amount);

        positions[params.owner][params.lower][params.upper] = cache.position;

        return (params.amount, state);
    }

    function remove(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
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
        if (params.amount == 0) return (0, state);
        if (params.amount > cache.position.liquidity) {
            revert NotEnoughPositionLiquidity();
        } else {
            /// @dev - validate user can remove from position using this function
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        tickNodes[params.upper].accumEpochLast > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        tickNodes[params.lower].accumEpochLast > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }

        Ticks.remove(
            ticks,
            tickNodes,
            state,
            params.lower,
            params.upper,
            params.amount,
            params.zeroForOne,
            true,
            true
        );

        {
            // update max deltas
            ICoverPoolStructs.Deltas memory tickDeltas = ticks[params.zeroForOne ? params.lower : params.upper].deltas;
            tickDeltas = Deltas.update(tickDeltas, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, false);
            ticks[params.zeroForOne ? params.lower : params.upper].deltas = tickDeltas;
        }

        cache.position.amountOut += uint128(
            params.zeroForOne
                ? DyDxMath.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                : DyDxMath.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
        );

        cache.position.liquidity -= uint128(params.amount);
        positions[params.owner][params.lower][params.upper] = cache.position;

        return (params.amount, state);
    }

    //TODO: pass pool as memory and save pool changes using return value
    function update(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        mapping(int24 => ICoverPoolStructs.TickNode) storage tickNodes,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState storage pool,
        ICoverPoolStructs.UpdateParams memory params
    )
        external
        returns (
            ICoverPoolStructs.GlobalState memory
        )
    {
        ICoverPoolStructs.UpdatePositionCache memory cache = ICoverPoolStructs.UpdatePositionCache({
            position: positions[params.owner][params.lower][params.upper],
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceClaim: TickMath.getSqrtRatioAtTick(params.claim),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceSpread: TickMath.getSqrtRatioAtTick(params.zeroForOne ? state.latestTick - state.tickSpread 
                                                                       : state.latestTick + state.tickSpread),
            amountInFilledMax: 0,
            amountOutUnfilledMax: 0,
            claimTick: ticks[params.claim],
            claimTickNode: tickNodes[params.claim],
            removeLower: true,
            removeUpper: true,
            deltas: ICoverPoolStructs.Deltas(0,0,0,0),
            finalDeltas: ICoverPoolStructs.Deltas(0,0,0,0)
        });

        // validate position liquidity
        if (params.amount > cache.position.liquidity) revert NotEnoughPositionLiquidity();
        if (cache.position.liquidity == 0) {
            return state;
        }
        // early return if no update
        if (
            (
                params.zeroForOne
                    ? params.claim == params.upper && cache.priceUpper != pool.price
                    : params.claim == params.lower && cache.priceLower != pool.price /// @dev - if pool price is start tick, set claimPriceLast to next tick crossed
            ) && params.claim == state.latestTick
        ) { if (cache.position.claimPriceLast == pool.price) return state; } /// @dev - nothing to update if pool price hasn't moved
        
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

        console.log('amountIn check:');
        console.log(cache.amountInFilledMax);
        console.log(cache.position.amountOut);
        console.log(cache.position.claimPriceLast);
        // section 2 - position start up to claim tick
        if (cache.position.claimPriceLast != cache.priceClaim) {
            // calculate if we at least cover one full tick
            console.log('section 2 check');
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
        } else if (params.zeroForOne ? cache.priceClaim > cache.position.claimPriceLast 
                                     : cache.priceClaim < cache.position.claimPriceLast) {
            /// @dev - second claim within current auction
            cache.priceClaim = pool.price;
        }
        // section 3 - current auction unfilled section
        if (params.claim == state.latestTick 
            && params.claim != (params.zeroForOne ? params.lower : params.upper)) {
                console.log('section 3 check');
            // if auction is live
            if (params.amount > 0) {
                // remove if burn
                uint128 amountOutRemoved = uint128(
                    params.zeroForOne
                        ? DyDxMath.getDx(params.amount, pool.price, cache.priceClaim, false)
                        : DyDxMath.getDy(params.amount, cache.priceClaim, pool.price, false)
                );
                cache.position.amountOut += amountOutRemoved;
                console.log(cache.position.amountOut);
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
                //TODO: update amountInDelta on pool at end
                //TODO: update amounIn/OutDeltaMax on lower : upper tick for section 3
                console.log(pool.liquidity);
            }
            // section 4 - current auction filled section
            {
                console.log('section 4 check');
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
                cache.amountInFilledMax += amountInFilledMax;
                console.log(pool.liquidity);
                uint256 poolAmountInDeltaChange = uint256(cache.position.liquidity) * 1e38 / uint256(pool.liquidity) * uint256(pool.amountInDelta) / 1e38;   
                cache.finalDeltas.amountInDelta += uint128(poolAmountInDeltaChange);
                pool.amountInDelta -= uint128(poolAmountInDeltaChange);
                console.log('new claim');
                console.log(cache.amountInFilledMax);
                console.log(cache.finalDeltas.amountInDelta);
                console.log(cache.amountInFilledMax - cache.deltas.amountInDelta);
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
            console.log('pool claims');
            console.log(pool.amountInDeltaMaxClaimed);
            console.log(pool.amountOutDeltaMaxClaimed);
            // modify claim price for section 5
            cache.priceClaim = cache.priceSpread;
        }
        // section 5 - burned liquidity past claim tick
        {
            if (params.amount > 0) {
                // update max deltas based on liquidity removed
                uint128 amountInOmitted; uint128 amountOutRemoved;
                (
                    amountInOmitted,
                    amountOutRemoved
                ) = Deltas.max(
                    params.amount,
                    cache.priceClaim,
                    params.zeroForOne ? cache.priceLower
                                      : cache.priceUpper,
                    params.zeroForOne
                );
                params.zeroForOne ? ticks[params.lower].deltas.amountInDeltaMax -= amountInOmitted
                                  : ticks[params.upper].deltas.amountInDeltaMax -= amountInOmitted;
                params.zeroForOne ? ticks[params.lower].deltas.amountOutDeltaMax -= amountOutRemoved
                                  : ticks[params.upper].deltas.amountOutDeltaMax -= amountOutRemoved;   
            }
        }
        // adjust based on deltas
        console.log('final deltas');
        console.log(cache.deltas.amountOutDelta);
        console.log(cache.amountInFilledMax);
        console.log(cache.amountOutUnfilledMax);
        if (cache.amountInFilledMax > 0) {
            // calculate deltas applied
            uint256 percentInDelta; uint256 percentOutDelta;
            if(cache.deltas.amountInDeltaMax > 0) {
                percentInDelta = uint256(cache.amountInFilledMax) * 1e38 / uint256(cache.deltas.amountInDeltaMax);
                if (cache.deltas.amountOutDeltaMax > 0) {
                    percentOutDelta = uint256(cache.amountOutUnfilledMax) * 1e38 / uint256(cache.deltas.amountOutDeltaMax);
                }
            }
            console.log(cache.deltas.amountInDelta);
            //TODO: also need to transfer maxes
            console.log('final deltas');
            console.log(cache.finalDeltas.amountInDelta);
            (cache.deltas, cache.finalDeltas) = Deltas.transfer(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
            (cache.deltas, cache.finalDeltas) = Deltas.transferMax(cache.deltas, cache.finalDeltas, percentInDelta, percentOutDelta);
            // apply deltas and add to position
            console.log('final deltas');
            console.log(cache.finalDeltas.amountInDelta);
            console.log(cache.amountInFilledMax);
            cache.position.amountIn  += uint128(cache.amountInFilledMax) - cache.finalDeltas.amountInDelta;
            cache.position.amountOut += cache.finalDeltas.amountOutDelta;
            
            // add remaining deltas cached back to claim tick
            // cache.deltas, cache.claimTick) = Deltas.stash(cache.deltas, cache.claimTick, 1e38, 1e38);
            if (params.claim != (params.zeroForOne ? params.lower : params.upper)) {
                // burn deltas on final tick of position
                console.log('tick deltas check');
                console.log(cache.deltas.amountInDelta);
                ICoverPoolStructs.Tick memory updateTick = ticks[params.zeroForOne ? params.lower : params.upper];
                (updateTick.deltas) = Deltas.burn(updateTick.deltas, cache.finalDeltas, true);
                console.log(cache.deltas.amountInDelta);
                ticks[params.zeroForOne ? params.lower : params.upper] = updateTick;
                console.log(cache.deltas.amountInDeltaMax);
                //TODO: handle partial stashed and partial on tick
                if (params.claim == (params.zeroForOne ? params.upper : params.lower)) {
                    (cache.deltas, cache.claimTick) = Deltas.to(cache.deltas, cache.claimTick);
                } else {
                    (cache.deltas, cache.claimTick) = Deltas.stash(cache.deltas, cache.claimTick);
                }
                console.log(cache.deltas.amountInDelta);
            } else {
                (cache.deltas, cache.claimTick) = Deltas.to(cache.deltas, cache.claimTick);
            }
            if (cache.position.amountIn == 1) {
                cache.position.amountIn = 0;
            }
        }

        // save claim tick and tick node
        ticks[params.claim] = cache.claimTick;
        tickNodes[params.claim] = cache.claimTickNode;
        // update pool liquidity
        pool.liquidity -= params.amount;
        
        /// @dev - mark last claim price
        cache.priceClaim = TickMath.getSqrtRatioAtTick(params.claim);
        cache.position.claimPriceLast = (params.claim == state.latestTick)
            ? pool.price
            : cache.priceClaim;
        /// @dev - if tick 0% filled, set CPL to latestTick
        if (pool.price == cache.priceSpread) cache.position.claimPriceLast = cache.priceClaim;
        /// @dev - if tick 100% filled, set CPL to next tick to unlock
        if (pool.price == cache.priceClaim && params.claim == state.latestTick) cache.position.claimPriceLast = cache.priceClaim;
        /// @dev - prior to Ticks.remove() so we don't overwrite liquidity delta changes
        // if burn or second mint
        //TODO: handle claim of current auction and second mint
        if ((params.amount > 0)) {
            if (params.claim != (params.zeroForOne ? params.upper : params.lower)) {
                //TODO: switch to being the current price if necessary
                params.zeroForOne ? cache.removeUpper = false : cache.removeLower = false;
            }
            Ticks.remove(
                ticks,
                tickNodes,
                state,
                params.zeroForOne ? params.lower : params.claim,
                params.zeroForOne ? params.claim : params.upper,
                uint128(uint128(params.amount)),
                params.zeroForOne,
                cache.removeLower,
                cache.removeUpper
            );
            cache.position.liquidity -= uint128(params.amount);
        }
        if (params.zeroForOne ? params.claim != params.upper 
                              : params.claim != params.lower) {
            // clear out position
            delete positions[params.owner][params.lower][params.upper];
        } 
        if (cache.position.liquidity == 0) {
            cache.position.accumEpochLast = 0;
            cache.position.claimPriceLast = 0;
            cache.position.claimCheckpoint = 0;
        }
        params.zeroForOne
            ? positions[params.owner][params.lower][params.claim] = cache.position
            : positions[params.owner][params.claim][params.upper] = cache.position;

        return state;
    }
}
