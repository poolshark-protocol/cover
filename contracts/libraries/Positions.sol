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
    error InvalidBurnPercentage();
    error PositionAmountZero();
    error PositionAuctionAmountTooSmall();
    error InvalidPositionBoundsOrder();
    error PositionInsideSafetyWindow();
    error NotEnoughPositionLiquidity();
    error NotImplementedYet();

    uint256 internal constant Q96 = 0x1000000000000000000000000;

    event Mint(
        address indexed owner,
        int24 indexed lower,
        int24 indexed upper,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityMinted,
        uint128 amountInDeltaMaxMinted,
        uint128 amountOutDeltaMaxMinted
    );

    event Burn(
        address indexed owner,
        address to,
        int24 indexed lower,
        int24 indexed upper,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityBurned,
        uint128 token0Amount,
        uint128 token1Amount,
        uint128 amountInDeltaMaxStashedBurned,
        uint128 amountOutDeltaMaxStashedBurned,
        uint128 amountInDeltaMaxBurned,
        uint128 amountOutDeltaMaxBurned
    );

    function resize(
        ICoverPoolStructs.Position memory position,
        ICoverPoolStructs.MintParams memory params,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.Immutables memory constants
    ) external pure returns (
        ICoverPoolStructs.MintParams memory,
        uint256
    )
    {
        _validate(params, constants);

        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: position,
            requiredStart: params.zeroForOne ? state.latestTick - int24(constants.tickSpread) * constants.minPositionWidth
                                             : state.latestTick + int24(constants.tickSpread) * constants.minPositionWidth,
            auctionCount: uint24((params.upper - params.lower) / constants.tickSpread),
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });

        // cannot mint empty position
        if (params.amount == 0) revert PositionAmountZero();

        // enforce safety window
        if (params.zeroForOne) {    
            if (params.lower >= cache.requiredStart) revert PositionInsideSafetyWindow(); 
        } else {
            if (params.upper <= cache.requiredStart) revert PositionInsideSafetyWindow();
        }

        cache.liquidityMinted = DyDxMath.getLiquidityForAmounts(
            cache.priceLower,
            cache.priceUpper,
            params.zeroForOne ? cache.priceLower : cache.priceUpper,
            params.zeroForOne ? 0 : uint256(params.amount),
            params.zeroForOne ? uint256(params.amount) : 0
        );

        // handle partial mints
        if (params.zeroForOne) {
            if (params.upper > cache.requiredStart) {
                params.upper = cache.requiredStart;
                uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(params.upper);
                params.amount -= uint128(
                    DyDxMath.getDx(cache.liquidityMinted, priceNewUpper, cache.priceUpper, false)
                );
                cache.priceUpper = uint160(priceNewUpper);
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / constants.tickSpread);
            if (cache.auctionCount == 0) revert InvalidPositionWidth();
        } else {
            if (params.lower < cache.requiredStart) {
                params.lower = cache.requiredStart;
                uint256 priceNewLower = TickMath.getSqrtRatioAtTick(params.lower);
                params.amount -= uint128(
                    DyDxMath.getDy(cache.liquidityMinted, cache.priceLower, priceNewLower, false)
                );
                cache.priceLower = uint160(priceNewLower);
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / constants.tickSpread);
            if (cache.auctionCount == 0) revert InvalidPositionWidth();
        }
        // enforce minimum position width
        if (cache.auctionCount < uint16(constants.minPositionWidth)) revert InvalidPositionWidth();
        if (cache.liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();

        // enforce minimum amount per auction
        _size(
            ICoverPoolStructs.SizeParams(
                cache.priceLower,
                cache.priceUpper,
                uint128(position.liquidity + cache.liquidityMinted),
                params.zeroForOne,
                state.latestTick,
                cache.auctionCount
            ),
            constants
        );
 
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
        ICoverPoolStructs.AddParams memory params,
        int16 tickSpread
    ) external returns (
        ICoverPoolStructs.GlobalState memory
    )    
    {
        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: positions[params.owner][params.lower][params.upper],
            requiredStart: 0,
            auctionCount: 0,
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });
        /// call if claim != lower and liquidity being added
        /// initialize new position
        if (params.amount == 0) return state;
        if (cache.position.liquidity == 0) {
            cache.position.accumEpochLast = state.accumEpoch;
        } else {
            // safety check in case we somehow get here
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        EpochMap.get(tickMap, TickMap.previous(tickMap, params.upper, tickSpread), tickSpread)
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(tickMap, TickMap.next(tickMap, params.lower, tickSpread), tickSpread)
                            > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }
        
        // add liquidity to ticks
        Ticks.insert(
            ticks,
            tickMap,
            state,
            params.lower,
            params.upper,
            uint128(params.amount),
            params.zeroForOne,
            tickSpread
        );

        // update liquidity global
        state.liquidityGlobal += params.amount;

        ICoverPoolStructs.Deltas memory mintDeltas;
        {
            // update max deltas
            ICoverPoolStructs.Tick memory finalTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (finalTick, mintDeltas) = Deltas.update(finalTick, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, true);
            ticks[params.zeroForOne ? params.lower : params.upper] = finalTick;
        }

        cache.position.liquidity += uint128(params.amount);

        positions[params.owner][params.lower][params.upper] = cache.position;

        emit Mint(
                params.owner,
                params.lower,
                params.upper,
                params.claim,
                params.zeroForOne,
                uint128(params.amount),
                mintDeltas.amountInDeltaMax,
                mintDeltas.amountOutDeltaMax
        );

        return state;
    }

    function remove(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.RemoveParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) external returns (uint128, ICoverPoolStructs.GlobalState memory) {
        // validate burn percentage
        if (params.amount > 1e38) revert InvalidBurnPercentage();
        // initialize cache
        ICoverPoolStructs.PositionCache memory cache = ICoverPoolStructs.PositionCache({
            position: positions[params.owner][params.lower][params.upper],
            requiredStart: params.zeroForOne ? state.latestTick - int24(constants.tickSpread) * constants.minPositionWidth
                                             : state.latestTick + int24(constants.tickSpread) * constants.minPositionWidth,
            auctionCount: uint24((params.upper - params.lower) / constants.tickSpread),
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });
        // convert percentage to liquidity amount
        params.amount = _convert(cache.position.liquidity, params.amount);
        // early return if no liquidity to remove
        if (params.amount == 0) return (0, state);
        if (params.amount > cache.position.liquidity) {
            revert NotEnoughPositionLiquidity();
        } else {
            _size(
                ICoverPoolStructs.SizeParams(
                    cache.priceLower,
                    cache.priceUpper,
                    cache.position.liquidity - params.amount,
                    params.zeroForOne,
                    state.latestTick,
                    cache.auctionCount
                ),
                constants
            );
            /// @dev - validate needed in case user passes in wrong tick
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        EpochMap.get(tickMap, TickMap.previous(tickMap, params.upper, constants.tickSpread), constants.tickSpread)
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(tickMap, TickMap.next(tickMap, params.lower, constants.tickSpread), constants.tickSpread)
                            > cache.position.accumEpochLast
            ) {
                revert WrongTickClaimedAt();
            }
        }

        Ticks.remove(
            ticks,
            tickMap,
            params.lower,
            params.upper,
            params.amount,
            params.zeroForOne,
            true,
            true,
            constants.tickSpread
        );

        // update liquidity global
        state.liquidityGlobal -= params.amount;

        ICoverPoolStructs.Deltas memory burnDeltas;
        {
            // update max deltas
            ICoverPoolStructs.Tick memory finalTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (finalTick, burnDeltas) = Deltas.update(finalTick, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, false);
            ticks[params.zeroForOne ? params.lower : params.upper] = finalTick;
        }

        cache.position.amountOut += uint128(
            params.zeroForOne
                ? DyDxMath.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                : DyDxMath.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
        );

        cache.position.liquidity -= uint128(params.amount);
        positions[params.owner][params.lower][params.upper] = cache.position;

        if (params.amount > 0) {
            emit Burn(
                    params.owner,
                    params.to,
                    params.lower,
                    params.upper,
                    params.zeroForOne ? params.upper : params.lower,
                    params.zeroForOne,
                    params.amount,
                    params.zeroForOne ? cache.position.amountOut : 0,
                    params.zeroForOne ? 0 : cache.position.amountOut,
                    0, 0,
                    burnDeltas.amountInDeltaMax,
                    burnDeltas.amountOutDeltaMax
            );
        }
        return (params.amount, state);
    }

    function update(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState storage pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) external returns (
            ICoverPoolStructs.GlobalState memory,
            int24
        )
    {
        ICoverPoolStructs.UpdatePositionCache memory cache;
        (
            cache,
            state
        ) = _deltas(
            positions,
            ticks,
            tickMap,
            state,
            pool,
            params,
            constants
        );

        if (cache.earlyReturn)
            return (state, params.claim);

        pool.amountInDelta = cache.pool.amountInDelta;
        pool.amountInDeltaMaxClaimed  = cache.pool.amountInDeltaMaxClaimed;
        pool.amountOutDeltaMaxClaimed = cache.pool.amountOutDeltaMaxClaimed;

        // save claim tick
        ticks[params.claim] = cache.claimTick;
        if (params.claim != (params.zeroForOne ? params.lower : params.upper))
            ticks[params.zeroForOne ? params.lower : params.upper] = cache.finalTick;
        
        // update pool liquidity
        if (state.latestTick == params.claim
            && params.claim != (params.zeroForOne ? params.lower : params.upper)
        ) pool.liquidity -= params.amount;
        
        if (params.amount > 0) {
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
                params.zeroForOne ? params.lower : params.claim,
                params.zeroForOne ? params.claim : params.upper,
                params.amount,
                params.zeroForOne,
                cache.removeLower,
                cache.removeUpper,
                constants.tickSpread
            );
            // update position liquidity
            cache.position.liquidity -= uint128(params.amount);
            // update global liquidity
            state.liquidityGlobal -= params.amount;
        }

        (
            cache,
            params
        ) = _checkpoint(state, pool, params, constants, cache);

        // clear out old position
        if (params.zeroForOne ? params.claim != params.upper 
                              : params.claim != params.lower) {
            /// @dev - this also clears out position end claims
            if (params.zeroForOne ? params.claim == params.lower 
                                  : params.claim == params.upper) {
                // subtract remaining position liquidity out from global
                state.liquidityGlobal -= cache.position.liquidity;
            }
            delete positions[params.owner][params.lower][params.upper];
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
        
        emit Burn(
            params.owner,
            params.to,
            params.lower,
            params.upper,
            params.claim,
            params.zeroForOne,
            params.amount,
            params.zeroForOne ? cache.position.amountOut : cache.position.amountIn,
            params.zeroForOne ? cache.position.amountIn  : cache.position.amountOut,
            uint128(cache.amountInFilledMax),
            uint128(cache.amountOutUnfilledMax),
            cache.finalDeltas.amountInDeltaMax,
            cache.finalDeltas.amountOutDeltaMax
        );
        // return cached position in memory and transfer out
        return (state, params.claim);
    }

    function snapshot(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState memory pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) external view returns (
        ICoverPoolStructs.Position memory
    ) {
        ICoverPoolStructs.UpdatePositionCache memory cache;
        (
            cache,
            state
        ) = _deltas(
            positions,
            ticks,
            tickMap,
            state,
            pool,
            params,
            constants
        );

        if (cache.earlyReturn) {
            if (params.amount > 0)
                cache.position.amountOut += uint128(
                    params.zeroForOne
                        ? DyDxMath.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                        : DyDxMath.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
                );
            return cache.position;
        }

        if (params.amount > 0) {
            cache.position.liquidity -= uint128(params.amount);
        }
        // checkpoint claimPriceLast
        (
            cache,
            params
        ) = _checkpoint(state, pool, params, constants, cache);
        
        // clear position values if empty
        if (cache.position.liquidity == 0) {
            cache.position.accumEpochLast = 0;
            cache.position.claimPriceLast = 0;
        }    
        return cache.position;
    }

    function _convert(
        uint128 liquidity,
        uint128 percent
    ) internal pure returns (
        uint128
    ) {
        // convert percentage to liquidity amount
        if (percent > 1e38) revert InvalidBurnPercentage();
        if (liquidity == 0 && percent > 0) revert NotEnoughPositionLiquidity();
        return uint128(uint256(liquidity) * uint256(percent) / 1e38);
    }

    function _deltas(
        mapping(address => mapping(int24 => mapping(int24 => ICoverPoolStructs.Position)))
            storage positions,
        mapping(int24 => ICoverPoolStructs.Tick) storage ticks,
        ICoverPoolStructs.TickMap storage tickMap,
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState memory pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) internal view returns (
        ICoverPoolStructs.UpdatePositionCache memory,
        ICoverPoolStructs.GlobalState memory
    ) {
        ICoverPoolStructs.UpdatePositionCache memory cache = ICoverPoolStructs.UpdatePositionCache({
            position: positions[params.owner][params.lower][params.upper],
            pool: pool,
            priceLower: TickMath.getSqrtRatioAtTick(params.lower),
            priceClaim: TickMath.getSqrtRatioAtTick(params.claim),
            priceUpper: TickMath.getSqrtRatioAtTick(params.upper),
            priceSpread: TickMath.getSqrtRatioAtTick(params.zeroForOne ? params.claim - constants.tickSpread 
                                                                       : params.claim + constants.tickSpread),
            amountInFilledMax: 0,
            amountOutUnfilledMax: 0,
            claimTick: ticks[params.claim],
            finalTick: ticks[params.zeroForOne ? params.lower : params.upper],
            earlyReturn: false,
            removeLower: true,
            removeUpper: true,
            deltas: ICoverPoolStructs.Deltas(0,0,0,0),
            finalDeltas: ICoverPoolStructs.Deltas(0,0,0,0)
        });

        params.amount = _convert(cache.position.liquidity, params.amount);

        // check claim is valid
        cache = Claims.validate(
            positions,
            tickMap,
            state,
            cache.pool,
            params,
            cache,
            constants
        );
        if (cache.earlyReturn) {
            return (cache, state);
        }
        if (params.amount > 0)
            _size(
                ICoverPoolStructs.SizeParams(
                    cache.priceLower,
                    cache.priceUpper,
                    cache.position.liquidity - params.amount,
                    params.zeroForOne,
                    state.latestTick,
                    uint24((params.upper - params.lower) / constants.tickSpread)
                ),
                constants
            );
        // get deltas from claim tick
        cache = Claims.getDeltas(cache, params);
        /// @dev - section 1 => position start - previous auction
        cache = Claims.section1(cache, params, constants);
        /// @dev - section 2 => position start -> claim tick
        cache = Claims.section2(cache, params);
        // check if auction in progress 
        if (params.claim == state.latestTick 
            && params.claim != (params.zeroForOne ? params.lower : params.upper)) {
            /// @dev - section 3 => claim tick - unfilled section
            cache = Claims.section3(cache, params, cache.pool);
            /// @dev - section 4 => claim tick - filled section
            cache = Claims.section4(cache, params, cache.pool);
        }
        /// @dev - section 5 => claim tick -> position end
        cache = Claims.section5(cache, params);
        // adjust position amounts based on deltas
        cache = Claims.applyDeltas(state, cache, params);

        return (cache, state);
    }

    function _validate(
        ICoverPoolStructs.MintParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) internal pure {
        // check for valid position bounds
        if (params.lower < TickMath.MIN_TICK / constants.tickSpread * constants.tickSpread) revert InvalidLowerTick();
        if (params.upper > TickMath.MAX_TICK / constants.tickSpread * constants.tickSpread) revert InvalidUpperTick();
        if (params.lower % int24(constants.tickSpread) != 0) revert InvalidLowerTick();
        if (params.upper % int24(constants.tickSpread) != 0) revert InvalidUpperTick();
        if (params.lower >= params.upper)
            revert InvalidPositionBoundsOrder();
    }

    function _size(
        ICoverPoolStructs.SizeParams memory params,
        ICoverPoolStructs.Immutables memory constants
    ) internal pure  
    {
        // early return if 100% of position burned
        if (params.liquidityAmount == 0 || params.auctionCount == 0) return;
        // set minAmountPerAuction based on token decimals
        uint256 minAmountPerAuction; bool denomTokenIn;
        if (params.latestTick > 0) {
            if (constants.minAmountLowerPriced) {
                // token1 is the lower priced token
                denomTokenIn = !params.zeroForOne;
                minAmountPerAuction = constants.minAmountPerAuction / 10**(18 - constants.token1Decimals);
            } else {
                // token0 is the higher priced token
                denomTokenIn = params.zeroForOne;
                minAmountPerAuction = constants.minAmountPerAuction / 10**(18 - constants.token0Decimals);
            }
        } else {
            if (constants.minAmountLowerPriced) {
                // token0 is the lower priced token
                denomTokenIn = params.zeroForOne;
                minAmountPerAuction = constants.minAmountPerAuction / 10**(18 - constants.token0Decimals);
            } else {
                // token1 is the higher priced token
                denomTokenIn = !params.zeroForOne;
                minAmountPerAuction = constants.minAmountPerAuction / 10**(18 - constants.token1Decimals);
            }
        }
        if (params.zeroForOne) {
            //calculate amount in the position currently
            uint128 amount = uint128(DyDxMath.getDx(
                params.liquidityAmount,
                params.priceLower,
                params.priceUpper,
                false
            ));
            if (denomTokenIn) {
                if (amount / params.auctionCount < minAmountPerAuction)
                    revert PositionAuctionAmountTooSmall();
            } else {
                // denominate in incoming token
                uint256 priceAverage = (params.priceUpper + params.priceLower) / 2;
                uint256 convertedAmount = amount * priceAverage / Q96 
                                                 * priceAverage / Q96; // convert by squaring price
                if (convertedAmount / params.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            }
        } else {
            uint128 amount = uint128(DyDxMath.getDy(
                params.liquidityAmount,
                params.priceLower,
                params.priceUpper,
                false
            ));
            if (denomTokenIn) {
                // denominate in token1
                // calculate amount in position currently
                if (amount / params.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            } else {
                // denominate in token0
                uint256 priceAverage = (params.priceUpper + params.priceLower) / 2;
                uint256 convertedAmount = amount * Q96 / priceAverage 
                                                 * Q96 / priceAverage; // convert by squaring price
                if (convertedAmount / params.auctionCount < minAmountPerAuction) 
                    revert PositionAuctionAmountTooSmall();
            }
        }
    }

    function _checkpoint(
        ICoverPoolStructs.GlobalState memory state,
        ICoverPoolStructs.PoolState memory pool,
        ICoverPoolStructs.UpdateParams memory params,
        ICoverPoolStructs.Immutables memory constants,
        ICoverPoolStructs.UpdatePositionCache memory cache
    ) internal pure returns (
        ICoverPoolStructs.UpdatePositionCache memory,
        ICoverPoolStructs.UpdateParams memory
    ) {
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
            params.claim = params.zeroForOne ? params.claim - constants.tickSpread
                                             : params.claim + constants.tickSpread;
        }
        return (cache, params);
    }
}
