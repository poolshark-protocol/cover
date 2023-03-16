// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './TickMath.sol';
import './Ticks.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './FullPrecisionMath.sol';
import './DyDxMath.sol';
import './Claims.sol';

/// @notice Position management library for ranged liquidity.
library Positions {
    error InvalidClaimTick();
    error LiquidityOverflow();
    error WrongTickClaimedAt();
    error PositionNotUpdated();
    error ClaimPriceLastNonZero();
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

    function validate(
        ICoverPoolStructs.MintParams memory params,
        ICoverPoolStructs.GlobalState memory state
    ) external pure returns (
        ICoverPoolStructs.MintParams memory,
        uint256 liquidityMinted
    )
    {
        if (params.lower < TickMath.MIN_TICK) revert InvalidLowerTick();
        if (params.upper > TickMath.MAX_TICK) revert InvalidUpperTick();
        if (params.lower % int24(state.tickSpread) != 0) revert InvalidLowerTick();
        if (params.upper % int24(state.tickSpread) != 0) revert InvalidUpperTick();
        if (params.amount == 0) revert InvalidPositionAmount();
        if (params.lower >= params.upper || params.lowerOld >= params.upperOld)
            revert InvalidPositionBoundsOrder();
        if (params.zeroForOne) {
            if (params.lower >= state.latestTick) revert InvalidPositionBoundsTwap();
        } else {
            if (params.upper <= state.latestTick) revert InvalidPositionBoundsTwap();
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
            if (params.upper >= state.latestTick) {
                params.upper = state.latestTick - int24(state.tickSpread);
                params.upperOld = state.latestTick;
                uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(params.upper);
                params.amount -= uint128(
                    DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper, false)
                );
                priceUpper = priceNewUpper;
            }
        } else {
            if (params.lower <= state.latestTick) {
                params.lower = state.latestTick + int24(state.tickSpread);
                params.lowerOld = state.latestTick;
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
            params,
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
    ) external {
        //TODO: dilute amountDeltas when adding liquidity
        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: positions[params.owner][params.lower][params.upper],
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper)
        });
        /// call if claim != lower and liquidity being added
        /// initialize new position
        if (params.amount == 0) return;
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
        // Positions.update() called first before additional mints
        if (cache.position.claimPriceLast > 0) { revert ClaimPriceLastNonZero(); }
        
        // add liquidity to ticks
        Ticks.insert(
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
            /// @dev - validate needed in case user passes in wrong tick
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
            0,
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

        // check claim is valid
        {
            bool earlyReturn;
            (cache, earlyReturn) = Claims.validate(
                positions,
                tickNodes,
                state,
                pool,
                params,
                cache
            );
            if (earlyReturn) {
                console.log('early return');
                console.log(cache.position.claimPriceLast);
                return state;
            }
        }
        // get deltas from claim tick
        cache = Claims.getDeltas(cache, params);
        
        /// @dev - section 1 => position start - previous auction
        cache = Claims.section1(cache, params, state);
        
        /// @dev - section 2 => position start -> claim tick
        cache = Claims.section2(ticks, cache, params, pool);
        
        // check if auction in progress 
        if (params.claim == state.latestTick 
            && params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            /// @dev - section 3 => claim tick - unfilled section
            cache = Claims.section3(ticks, cache, params, pool);
            
            /// @dev - section 4 => claim tick - filled section
            cache = Claims.section4(cache, params, pool);
        }

        /// @dev - section 5 => claim tick -> position end
        cache = Claims.section5(ticks, cache, params);
        
        // adjust position amounts based on deltas
        cache = Claims.applyDeltas(ticks, cache, params);

        // save claim tick and tick node
        ticks[params.claim] = cache.claimTick;
        tickNodes[params.claim] = cache.claimTickNode;
        
        // update pool liquidity
        if (state.latestTick == params.claim
            && params.claim != (params.zeroForOne ? params.lower : params.upper)
        ) pool.liquidity -= params.amount;
        
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
                cache.position.liquidityStashed,
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
