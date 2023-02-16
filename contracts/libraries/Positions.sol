// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import './Ticks.sol';
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
        if (params.lower % int24(params.state.tickSpread) != 0) revert InvalidLowerTick();
        //TODO: latestTick should never be MAX_TICK or MIN_TICK
        if (params.lower < TickMath.MIN_TICK) revert InvalidLowerTick();
        if (params.upper % int24(params.state.tickSpread) != 0) revert InvalidUpperTick();
        if (params.upper > TickMath.MAX_TICK) revert InvalidUpperTick();
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
            cache.position.claimPriceLast = params.zeroForOne
                ? uint160(cache.priceUpper)
                : uint160(cache.priceLower);
            /// @dev - CPL is left zero so only first claim we apply deltas
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

        // /// validate mint amount is not over max tick liquidity
        // if (amount > 0 && uint128(amount) + cache.position.liquidity > MAX_TICK_LIQUIDITY) revert MaxTickLiquidity();

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
            uint128(params.amount),
            params.zeroForOne,
            true,
            true
        );

        cache.position.amountOut += uint128(
            params.zeroForOne
                ? DyDxMath.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                : DyDxMath.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
        );

        cache.position.liquidity -= uint128(params.amount);
        positions[params.owner][params.lower][params.upper] = cache.position;

        return (params.amount, state);
    }

    //TODO: factor in deltas in current auction after implementing GDA
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
            claimTick: tickNodes[params.claim],
            removeLower: true,
            removeUpper: true,
            amountInDelta: params.claim == state.latestTick ? pool.amountInDelta : 0,
            amountOutDelta: 0,
            amountInCoverage: 0
        });

        // validate position liquidity
        if (cache.position.liquidity == 0) {
            if (params.amount > 0) revert NotEnoughPositionLiquidity();
            return state;
        }

        // claim param sanity check
        if (
            (
                params.zeroForOne
                    ? params.claim == params.upper && cache.priceUpper != pool.price
                    : params.claim == params.lower && cache.priceLower != pool.price /// @dev - if pool price is start tick, set claimPriceLast to next tick crossed
            ) && params.claim == state.latestTick
        ) { if (cache.position.claimPriceLast == pool.price) return state; } /// @dev - nothing to update if pool price hasn't moved
        else if (
            (
                params.zeroForOne
                    ? cache.position.claimPriceLast < cache.priceClaim
                    : cache.position.claimPriceLast > cache.priceClaim
            ) && params.claim != state.latestTick
        ) revert InvalidClaimTick(); /// @dev - wrong claim tick
        if (params.claim < params.lower || params.claim > params.upper) revert InvalidClaimTick();

        // validate claim tick
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
             if (cache.claimTick.accumEpochLast <= cache.position.accumEpochLast)
                revert WrongTickClaimedAt();
            params.zeroForOne ? cache.removeLower = false : cache.removeUpper = false;
        } else {
            // zero fill or partial fill
            uint32 claimNextTickAccumEpoch = params.zeroForOne
                ? tickNodes[cache.claimTick.previousTick].accumEpochLast
                : tickNodes[cache.claimTick.nextTick].accumEpochLast;
            ///@dev - next accumEpoch should not be greater
            if (claimNextTickAccumEpoch > cache.position.accumEpochLast)
                revert WrongTickClaimedAt();

            // check if liquidity removal required
            if (params.amount > 0) {
                /// @dev - check if liquidity removal required
                cache.removeLower = params.zeroForOne
                    ? true
                    : tickNodes[cache.claimTick.nextTick].accumEpochLast <=
                        cache.position.accumEpochLast;
                cache.removeUpper = params.zeroForOne
                    ? tickNodes[cache.claimTick.previousTick].accumEpochLast <=
                        cache.position.accumEpochLast
                    : true;
            }
        }
        
        // calculate section 1 of claim
        if (params.zeroForOne ? cache.priceClaim < cache.position.claimPriceLast 
                              : cache.priceClaim > cache.position.claimPriceLast) {
            /// @dev - only calculate if we at least cover one full tick
            uint256 amountInClaimable = params.zeroForOne
                ? DyDxMath.getDy(
                    cache.position.liquidity,
                    cache.priceClaim,
                    cache.position.claimPriceLast,
                    false
                )
                : DyDxMath.getDx(
                    cache.position.liquidity,
                    cache.position.claimPriceLast,
                    cache.priceClaim,
                    false
                );
            cache.position.amountIn += uint128(amountInClaimable);
            cache.amountInCoverage = amountInClaimable;
        } else if (params.zeroForOne ? cache.priceClaim > cache.position.claimPriceLast 
                                     : cache.priceClaim < cache.position.claimPriceLast) {
            /// @dev - second claim within current auction
            cache.priceClaim = pool.price;
            cache.amountInDelta = pool.amountInDelta - cache.position.amountInDeltaLast;
        }

        // factor in current liquidity auction
        if (params.claim == state.latestTick && params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            // section 2
            if (params.amount > 0) {
                // remove if burn
                cache.position.amountOut += uint128(
                    params.zeroForOne
                        ? DyDxMath.getDx(params.amount, pool.price, cache.priceClaim, false)
                        : DyDxMath.getDy(params.amount, cache.priceClaim, pool.price, false)
                );
                cache.amountInCoverage +=
                    params.zeroForOne
                        ? DyDxMath.getDy(params.amount, pool.price, cache.priceClaim, true)
                        : DyDxMath.getDx(params.amount, cache.priceClaim, pool.price, true)
                ;
                if (pool.liquidity == params.amount) {
                    pool.amountInDelta = 0;
                }
                pool.liquidity -= params.amount;
            }
            // section 3
            {
                // modify claim price for section 4
                cache.priceClaim = cache.priceSpread;
                uint256 amountInSection3 =
                    params.zeroForOne
                        ? DyDxMath.getDy(
                            cache.position.liquidity, // multiplied by liquidity later
                            cache.position.claimPriceLast < cache.priceClaim ? cache.position.claimPriceLast : cache.priceSpread,
                            pool.price,
                            false
                        )
                        : DyDxMath.getDx(
                            cache.position.liquidity,
                            pool.price,
                            cache.position.claimPriceLast > cache.priceClaim ? cache.position.claimPriceLast : cache.priceSpread,
                            false
                        );
                cache.position.amountIn += uint128(amountInSection3);
                cache.amountInCoverage += amountInSection3;
                cache.position.amountInDeltaLast = pool.amountInDelta;
            }
        } else {
            cache.position.amountInDeltaLast = 0;
        }

        // section 4
        {

            if (params.amount > 0) {
                cache.position.amountOut += uint128(
                    params.zeroForOne
                        ? DyDxMath.getDx(uint128(params.amount), cache.priceLower, cache.priceClaim, false)
                        : DyDxMath.getDy(uint128(params.amount), cache.priceClaim, cache.priceUpper, false)
                );
                cache.amountInCoverage +=
                    params.zeroForOne
                        ? DyDxMath.getDy(uint128(params.amount), cache.priceLower, cache.priceClaim, false)
                        : DyDxMath.getDx(uint128(params.amount), cache.priceClaim, cache.priceUpper, false)
                ;
            }
        }

        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {         
            /// @dev - ignore delta carry for 100% fill
            cache.amountInDelta = uint128(
                uint256(ticks[params.claim].amountInDelta) -
                    (uint256(ticks[params.claim].amountInDeltaCarryPercent) *
                        ticks[params.claim].amountInDelta) /
                    1e18
            );
            cache.amountOutDelta = uint128(
                uint256(ticks[params.claim].amountOutDelta) -
                    (uint256(ticks[params.claim].amountOutDeltaCarryPercent) *
                        ticks[params.claim].amountInDelta) /
                    1e18
            );
        } else {
            if (params.claim != (params.zeroForOne ? params.upper : params.lower)) {
                // clear out position amountInDeltaLast
                cache.position.amountInDeltaLast = 0;
                // factor in tick and carry deltas for middle of position
                cache.amountInDelta += ticks[params.claim].amountInDelta;
                cache.amountOutDelta += ticks[params.claim].amountOutDelta;
            } else {
                // factor in carry deltas for start of position
                cache.amountInDelta += ticks[params.claim].amountInDelta * ticks[params.claim].amountInDeltaCarryPercent / 1e18;
                cache.amountOutDelta += ticks[params.claim].amountOutDelta * ticks[params.claim].amountOutDeltaCarryPercent / 1e18;
            }
            
        }
        // factor in deltas for section 1
        // console.log('section 1 before deltas');
        // console.log(cache.position.amountIn);
        if (cache.amountInDelta > 0) {
            uint256 amountInCoverageFull =
                    params.zeroForOne
                        ? DyDxMath.getDy(cache.position.liquidity, cache.priceLower, cache.priceUpper, false)
                        : DyDxMath.getDx(cache.position.liquidity, cache.priceLower, cache.priceUpper, false)
            ;
            //TODO: handle underflow here
            // cache.amountInDelta = cache.amountInDelta * cache.amountInCoverage / amountInCoverageFull;
            // cache.amountOutDelta = cache.amountOutDelta * cache.amountInCoverage / amountInCoverageFull;
            cache.amountInDelta = uint128(FullPrecisionMath.mulDivRoundingUp(uint256(cache.amountInDelta) , cache.amountInCoverage, amountInCoverageFull));
            cache.position.amountIn -= uint128(
                FullPrecisionMath.mulDiv(cache.amountInDelta, cache.position.liquidity, Q96) + 1
            );
            if (cache.amountOutDelta > 0) {
                cache.position.amountOut += uint128(
                    FullPrecisionMath.mulDiv(
                        uint128(cache.amountOutDelta),
                        cache.position.liquidity,
                        Q96
                    )
                );
            }
            /// @auditor - how should we handle this for rounding^
        } /// @dev - amountInDelta always lt 0
        // factor in swap fees
        cache.position.amountIn = (cache.position.amountIn * 1e6) / (1e6 - state.swapFee);
        /// @dev - mark last claim price
        cache.position.claimPriceLast = (params.claim == state.latestTick)
            ? pool.price
            : cache.priceClaim;
        /// @dev - if tick 0% filled, set CPL to latestTick
        if (pool.price == cache.priceSpread) cache.position.claimPriceLast = cache.priceClaim;
        /// @dev - if tick 100% filled, set CPL to next tick to unlock
        if (pool.price == cache.priceClaim) cache.position.claimPriceLast = cache.priceSpread;

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
            // they should also get params.amountOutDeltaCarry
        }
        if (params.zeroForOne ? params.claim != params.upper : params.claim != params.lower) {
            ///TODO: do tick insert here
            // handle double minting of position
            delete positions[params.owner][params.lower][params.upper];
            //TODO: handle liquidity overflow in mint call
        }

        params.zeroForOne
            ? positions[params.owner][params.lower][params.claim] = cache.position
            : positions[params.owner][params.claim][params.upper] = cache.position;

        return state;
    }
}
