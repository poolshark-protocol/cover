// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './math/TickMath.sol';
import './Ticks.sol';
import './Deltas.sol';
import '../interfaces/ICoverPoolStructs.sol';
import './math/FullPrecisionMath.sol';
import './math/DyDxMath.sol';
import './Claims.sol';
import './EpochMap.sol';

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
    error InvalidPositionWidth();
    error PositionAmountZero();
    error PositionAuctionAmountTooSmall();
    error InvalidPositionBoundsOrder();
    error PositionInsideSafetyWindow();
    error NotEnoughPositionLiquidity();
    error NotImplementedYet();

    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    int24  internal constant MIN_POSITION_WIDTH = 5; //TODO: move to CoverPoolManager

    function validate(
        ICoverPoolStructs.MintParams memory params,
        ICoverPoolStructs.GlobalState memory state,
        uint8   token0Decimals,
        uint8   token1Decimals,
        int16   minPositionWidth,
        uint256 minAmountPerAuction,
        bool    minLowerPricedToken
    ) external pure returns (
        ICoverPoolStructs.MintParams memory,
        uint256
    )
    {
        ICoverPoolStructs.ValidateCache memory cache = ICoverPoolStructs.ValidateCache({
            requiredStart: params.zeroForOne ? state.latestTick - int24(state.tickSpread) * minPositionWidth
                                             : state.latestTick + int24(state.tickSpread) * minPositionWidth,
            auctionCount: uint24((params.upper - params.lower) / state.tickSpread),
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });

        // check for valid position bounds
        if (params.lower < TickMath.MIN_TICK) revert InvalidLowerTick();
        if (params.upper > TickMath.MAX_TICK) revert InvalidUpperTick();
        if (params.lower % int24(state.tickSpread) != 0) revert InvalidLowerTick();
        if (params.upper % int24(state.tickSpread) != 0) revert InvalidUpperTick();
        if (params.amount == 0) revert PositionAmountZero();
        if (params.lower >= params.upper)
            revert InvalidPositionBoundsOrder();

        // enforce safety window
        if (params.zeroForOne) {    
            if (params.lower > cache.requiredStart) revert PositionInsideSafetyWindow(); 
        } else {
            if (params.upper < cache.requiredStart) revert PositionInsideSafetyWindow();
        }

        cache.liquidityMinted = DyDxMath.getLiquidityForAmounts(
            cache.priceLower,
            cache.priceUpper,
            params.zeroForOne ? cache.priceLower : cache.priceUpper,
            params.zeroForOne ? 0 : uint256(params.amount),
            params.zeroForOne ? uint256(params.amount) : 0
        );

        // set minAmountPerAuction based on token decimals
        if (state.latestTick > 0) {
            if (minLowerPricedToken) {
                // token1 is the lower priced token
                cache.denomTokenIn = !params.zeroForOne;
                minAmountPerAuction = minAmountPerAuction / 10**(18 - token1Decimals);
            } else {
                // token0 is the higher priced token
                cache.denomTokenIn = params.zeroForOne;
                minAmountPerAuction = minAmountPerAuction / 10**(18 - token0Decimals);
            }
        } else {
            if (minLowerPricedToken) {
                // token0 is the lower priced token
                cache.denomTokenIn = params.zeroForOne;
                minAmountPerAuction = minAmountPerAuction / 10**(18 - token0Decimals);
            } else {
                // token1 is the higher priced token
                cache.denomTokenIn = !params.zeroForOne;
                minAmountPerAuction = minAmountPerAuction / 10**(18 - token1Decimals);
            }
        }

        // handle partial mints
        if (params.zeroForOne) {
            if (params.upper >= state.latestTick) {
                params.upper = state.latestTick - int24(state.tickSpread);
                uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(params.upper);
                params.amount -= uint128(
                    DyDxMath.getDx(cache.liquidityMinted, priceNewUpper, cache.priceUpper, false)
                );
                cache.priceUpper = priceNewUpper;
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / state.tickSpread);
            if (cache.auctionCount == 0) revert InvalidPositionWidth();
            // enforce minimum amount per auction
            if (!cache.denomTokenIn) {
                // denominate in incoming token
                cache.priceAverage = (cache.priceUpper + cache.priceLower) / 2;
                uint256 convertedAmount = params.amount * cache.priceAverage / Q96 
                                                        * cache.priceAverage / Q96; // convert by squaring price
                if (convertedAmount / cache.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            } else {
                if (params.amount / cache.auctionCount < minAmountPerAuction)
                    revert PositionAuctionAmountTooSmall();
            }
        } else {
            if (params.lower <= state.latestTick) {
                params.lower = state.latestTick + int24(state.tickSpread);
                uint256 priceNewLower = TickMath.getSqrtRatioAtTick(params.lower);
                params.amount -= uint128(
                    DyDxMath.getDy(cache.liquidityMinted, cache.priceLower, priceNewLower, false)
                );
                cache.priceLower = priceNewLower;
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / state.tickSpread);
            if (cache.auctionCount == 0) revert InvalidPositionWidth();
            // enforce minimum amount per auction
            if (cache.denomTokenIn) {
                // denominate in token1
                minAmountPerAuction = minAmountPerAuction / 10**(18 - token1Decimals);
                if (params.amount / cache.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            } else {
                // denominate in token0
                cache.priceAverage = (cache.priceUpper + cache.priceLower) / 2;
                uint256 convertedAmount = params.amount * Q96 / cache.priceAverage 
                                                        * Q96 / cache.priceAverage; // convert by squaring price
                if (convertedAmount / cache.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            }
        }
        // enforce minimum position width
        if (cache.auctionCount < uint16(minPositionWidth)) revert InvalidPositionWidth();
        if (cache.liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();
 
        return (
            params,
            cache.liquidityMinted
        );
    }

    function add(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
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
            // safety check in case we somehow get here
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        EpochMap.get(tickMap, TickMap.previous(tickMap, params.upper))
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(tickMap, TickMap.next(tickMap, params.lower))
                            > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }
        // Positions.update() called first before additional mints
        // if (cache.position.claimPriceLast != 0) { revert ClaimPriceLastNonZero(); }
        
        // add liquidity to ticks
        Ticks.insert(
            ticks,
            tickMap,
            state,
            params.lower,
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
        ICoverPoolStructs.TickMap storage tickMap,
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
                        EpochMap.get(tickMap, TickMap.previous(tickMap, params.upper))
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(tickMap, TickMap.next(tickMap, params.lower))
                            > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }

        Ticks.remove(
            ticks,
            tickMap,
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
        //TODO: emit Burn event here
        return (params.amount, state);
    }

    //TODO: pass pool as memory and save pool changes using return value
    function update(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState storage pool,
        ICoverPoolStructs.UpdateParams memory params
    ) external returns (
            ICoverPoolStructs.GlobalState memory,
            int24
        )
    {
        ICoverPoolStructs.UpdatePositionCache memory cache = ICoverPoolStructs.UpdatePositionCache({
            position: positions[params.owner][params.lower][params.upper],
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceClaim: TickMath.getSqrtRatioAtTick(params.claim),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceSpread: TickMath.getSqrtRatioAtTick(params.zeroForOne ? params.claim - state.tickSpread 
                                                                       : params.claim + state.tickSpread),
            amountInFilledMax: 0,
            amountOutUnfilledMax: 0,
            claimTick: ticks[params.claim],
            finalTick: ticks[params.zeroForOne ? params.lower : params.upper],
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
                tickMap,
                state,
                pool,
                params,
                cache
            );
            if (earlyReturn) {
                return (state, params.claim);
            }
        }
        // get deltas from claim tick
        cache = Claims.getDeltas(cache, params);
        /// @dev - section 1 => position start - previous auction
        cache = Claims.section1(cache, params, state);
        /// @dev - section 2 => position start -> claim tick
        cache = Claims.section2(cache, params);
        // check if auction in progress 
        if (params.claim == state.latestTick 
            && params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            /// @dev - section 3 => claim tick - unfilled section
            cache = Claims.section3(ticks, cache, params, pool);
            /// @dev - section 4 => claim tick - filled section
            cache = Claims.section4(cache, params, pool);
        }

        /// @dev - section 5 => claim tick -> position end
        cache = Claims.section5(cache, params);
        // adjust position amounts based on deltas
        cache = Claims.applyDeltas(ticks, cache, params);
        // save claim tick
        ticks[params.claim] = cache.claimTick;
        
        // update pool liquidity
        if (state.latestTick == params.claim
            && params.claim != (params.zeroForOne ? params.lower : params.upper)
        ) pool.liquidity -= params.amount;
        
        /// @dev - mark last claim price

        /// @dev - prior to Ticks.remove() so we don't overwrite liquidity delta changes
        // if burn or second mint
        //TODO: handle claim of current auction and second mint
        
        if ((params.amount > 0)) {
            if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
                // only remove once if final tick of position
                cache.removeLower = false;
                cache.removeUpper = false;
            } else {
                params.zeroForOne ? cache.removeUpper = true 
                                  : cache.removeLower = true;
            }
            Ticks.remove(
                ticks,
                tickMap,
                state,
                params.zeroForOne ? params.lower : params.claim,
                params.zeroForOne ? params.claim : params.upper,
                params.amount,
                params.zeroForOne,
                cache.removeLower,
                cache.removeUpper
            );
            cache.position.liquidity -= uint128(params.amount);
        }

        // update claimPriceLast
        cache.priceClaim = TickMath.getSqrtRatioAtTick(params.claim);
        cache.position.claimPriceLast = (params.claim == state.latestTick)
            ? pool.price
            : cache.priceClaim;
        /// @dev - if tick 0% filled, set CPL to latestTick
        if (pool.price == cache.priceSpread) cache.position.claimPriceLast = cache.priceClaim;
        /// @dev - if tick 100% filled, set CPL to next tick to unlock
        if (pool.price == cache.priceClaim && params.claim == state.latestTick){
            cache.position.claimPriceLast = cache.priceSpread;
            // set claim tick to claim + tickSpread
            params.claim = params.zeroForOne ? params.claim - state.tickSpread
                                             : params.claim + state.tickSpread;
        }

        // clear out old position
        if (params.zeroForOne ? params.claim != params.upper 
                              : params.claim != params.lower) {
            /// @dev - this also clears out position end claims
            delete positions[params.owner][params.lower][params.upper];
        } else {
            // save position
        }
        // force collection to the user
        // store cached position in memory
        if (cache.position.liquidity == 0) {
            cache.position.accumEpochLast = 0;
            cache.position.claimPriceLast = 0;
        }
        params.zeroForOne
            ? positions[params.owner][params.lower][params.claim] = cache.position
            : positions[params.owner][params.claim][params.upper] = cache.position;
        // return cached position in memory and transfer out
        return (state, params.claim);
    }
}
