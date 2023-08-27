// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './Ticks.sol';
import './Deltas.sol';
import '../interfaces/structs/CoverPoolStructs.sol';
import '../interfaces/ICoverPool.sol';
import './math/OverflowMath.sol';
import './Claims.sol';
import './EpochMap.sol';

/// @notice Position management library for ranged liquidity.
library Positions {
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    event Mint(
        address indexed to,
        int24 lower,
        int24 upper,
        bool zeroForOne,
        uint32 positionId,
        uint32 epochLast,
        uint128 amountIn,
        uint128 liquidityMinted,
        uint128 amountInDeltaMaxMinted,
        uint128 amountOutDeltaMaxMinted
    );

    event Burn(
        address indexed to,
        uint32 positionId,
        int24 claim,
        bool zeroForOne,
        uint128 liquidityBurned,
        uint128 tokenInClaimed,
        uint128 tokenOutClaimed,
        uint128 tokenOutBurned,
        uint128 amountInDeltaMaxStashedBurned,
        uint128 amountOutDeltaMaxStashedBurned,
        uint128 amountInDeltaMaxBurned,
        uint128 amountOutDeltaMaxBurned,
        uint160 claimPriceLast
    );

    function resize(
        CoverPoolStructs.CoverPosition memory position,
        ICoverPool.MintParams memory params,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.Immutables memory constants
    ) internal pure returns (
        ICoverPool.MintParams memory,
        uint256
    )
    {
        ConstantProduct.checkTicks(params.lower, params.upper, constants.tickSpread);

        CoverPoolStructs.CoverPositionCache memory cache = CoverPoolStructs.CoverPositionCache({
            position: position,
            deltas: CoverPoolStructs.Deltas(0,0,0,0),
            requiredStart: params.zeroForOne ? state.latestTick - int24(constants.tickSpread) * constants.minPositionWidth
                                             : state.latestTick + int24(constants.tickSpread) * constants.minPositionWidth,
            auctionCount: uint24((params.upper - params.lower) / constants.tickSpread),
            priceLower: ConstantProduct.getPriceAtTick(params.lower, constants),
            priceUpper: ConstantProduct.getPriceAtTick(params.upper, constants),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });

        // cannot mint empty position
        if (params.amount == 0) require (false, 'PositionAmountZero()');

        // enforce safety window
        if (params.zeroForOne) {    
            if (params.lower >= cache.requiredStart) require (false, 'PositionInsideSafetyWindow()'); 
        } else {
            if (params.upper <= cache.requiredStart) require (false, 'PositionInsideSafetyWindow()');
        }

        cache.liquidityMinted = ConstantProduct.getLiquidityForAmounts(
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
                uint256 priceNewUpper = ConstantProduct.getPriceAtTick(params.upper, constants);
                params.amount -= uint128(
                    ConstantProduct.getDx(cache.liquidityMinted, priceNewUpper, cache.priceUpper, false)
                );
                cache.priceUpper = uint160(priceNewUpper);
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / constants.tickSpread);
            if (cache.auctionCount == 0) require (false, 'InvalidPositionWidth()');
        } else {
            if (params.lower < cache.requiredStart) {
                params.lower = cache.requiredStart;
                uint256 priceNewLower = ConstantProduct.getPriceAtTick(params.lower, constants);
                params.amount -= uint128(
                    ConstantProduct.getDy(cache.liquidityMinted, cache.priceLower, priceNewLower, false)
                );
                cache.priceLower = uint160(priceNewLower);
            }
            // update auction count
            cache.auctionCount = uint24((params.upper - params.lower) / constants.tickSpread);
            if (cache.auctionCount == 0) require (false, 'InvalidPositionWidth()');
        }
        // enforce minimum position width
        if (cache.auctionCount < uint16(constants.minPositionWidth)) require (false, 'InvalidPositionWidth()');
        if (cache.liquidityMinted > uint128(type(int128).max)) require (false, 'LiquidityOverflow()');

        // enforce minimum amount per auction
        _size(
            CoverPoolStructs.SizeParams(
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
       CoverPoolStructs.CoverPosition memory position,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.AddParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) internal returns (
        CoverPoolStructs.GlobalState memory,
        CoverPoolStructs.CoverPosition memory
    ) {
        if (params.amount == 0) return (state, position);
        // initialize cache
        CoverPoolStructs.CoverPositionCache memory cache = CoverPoolStructs.CoverPositionCache({
            position: position,
            deltas: CoverPoolStructs.Deltas(0,0,0,0),
            requiredStart: 0,
            auctionCount: 0,
            priceLower: ConstantProduct.getPriceAtTick(params.lower, constants),
            priceUpper: ConstantProduct.getPriceAtTick(params.upper, constants),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });
        /// call if claim != lower and liquidity being added
        /// initialize new position

        if (cache.position.liquidity == 0) {
            cache.position.accumEpochLast = state.accumEpoch;
        } else {
            // safety check in case we somehow get here
            if (
                params.zeroForOne
                    ? state.latestTick < params.upper ||
                        EpochMap.get(TickMap.previous(params.upper, tickMap, constants), params.zeroForOne, tickMap, constants)
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(TickMap.next(params.lower, tickMap, constants), params.zeroForOne, tickMap, constants)
                            > cache.position.accumEpochLast
            ) {
                require (false, string.concat('UpdatePositionFirstAt(', String.from(params.lower), ', ', String.from(params.upper), ')'));
            }
        }
        
        // add liquidity to ticks
        Ticks.insert(
            ticks,
            tickMap,
            state,
            constants,
            params.lower,
            params.upper,
            uint128(params.amount),
            params.zeroForOne
        );

        // update liquidity global
        state.liquidityGlobal += params.amount;

        {
            // update max deltas
            CoverPoolStructs.Tick memory finalTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (finalTick, cache.deltas) = Deltas.update(finalTick, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, true);
            ticks[params.zeroForOne ? params.lower : params.upper] = finalTick;
            // revert if either max delta is zero
            if (cache.deltas.amountInDeltaMax == 0) {
                require(false, 'AmountInDeltaIsZero()');
            } else if (cache.deltas.amountOutDeltaMax == 0)
                require(false, 'AmountOutDeltaIsZero()');
        }
        cache.position.liquidity += uint128(params.amount);
        emit Mint(
            params.to,
            params.lower,
            params.upper,
            params.zeroForOne,
            params.positionId,
            state.accumEpoch,
            params.amountIn,
            params.amount,
            cache.deltas.amountInDeltaMax,
            cache.deltas.amountOutDeltaMax
        );

        return (state, cache.position);
    }

    function remove(
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.RemoveParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) internal returns (uint128, CoverPoolStructs.GlobalState memory) {
        // validate burn percentage
        if (params.amount > 1e38) require (false, 'InvalidBurnPercentage()');
        // initialize cache
        CoverPoolStructs.CoverPositionCache memory cache = CoverPoolStructs.CoverPositionCache({
            position: positions[params.positionId],
            deltas: CoverPoolStructs.Deltas(0,0,0,0),
            requiredStart: params.zeroForOne ? state.latestTick - int24(constants.tickSpread) * constants.minPositionWidth
                                             : state.latestTick + int24(constants.tickSpread) * constants.minPositionWidth,
            auctionCount: uint24((params.upper - params.lower) / constants.tickSpread),
            priceLower: ConstantProduct.getPriceAtTick(params.lower, constants),
            priceUpper: ConstantProduct.getPriceAtTick(params.upper, constants),
            priceAverage: 0,
            liquidityMinted: 0,
            denomTokenIn: true
        });
        // convert percentage to liquidity amount
        params.amount = _convert(cache.position.liquidity, params.amount);
        // early return if no liquidity to remove
        if (params.amount == 0) return (0, state);
        if (params.amount > cache.position.liquidity) {
            require (false, 'NotEnoughPositionLiquidity()');
        } else {
            _size(
                CoverPoolStructs.SizeParams(
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
                        EpochMap.get(TickMap.previous(params.upper, tickMap, constants), params.zeroForOne, tickMap, constants)
                            > cache.position.accumEpochLast
                    : state.latestTick > params.lower ||
                        EpochMap.get(TickMap.next(params.lower, tickMap, constants), params.zeroForOne, tickMap, constants)
                            > cache.position.accumEpochLast
            ) {
                require (false, 'WrongTickClaimedAt()');
            }
        }

        Ticks.remove(
            ticks,
            tickMap,
            constants,
            params.lower,
            params.upper,
            params.amount,
            params.zeroForOne,
            true,
            true
        );

        // update liquidity global
        state.liquidityGlobal -= params.amount;

        {
            // update max deltas
            CoverPoolStructs.Tick memory finalTick = ticks[params.zeroForOne ? params.lower : params.upper];
            (finalTick, cache.deltas) = Deltas.update(finalTick, params.amount, cache.priceLower, cache.priceUpper, params.zeroForOne, false);
            ticks[params.zeroForOne ? params.lower : params.upper] = finalTick;
        }

        cache.position.amountOut += uint128(
            params.zeroForOne
                ? ConstantProduct.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                : ConstantProduct.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
        );

        cache.position.liquidity -= uint128(params.amount);
        if (cache.position.liquidity == 0) {
            cache.position.owner = address(0);
            cache.position.lower = 0;
            cache.position.upper = 0;
        }
        positions[params.positionId] = cache.position;

        if (params.amount > 0) {
            emit Burn(
                    params.to,
                    params.positionId,
                    params.zeroForOne ? params.upper : params.lower,
                    params.zeroForOne,
                    params.amount,
                    0, 0,
                    cache.position.amountOut,
                    0, 0,
                    cache.deltas.amountInDeltaMax,
                    cache.deltas.amountOutDeltaMax,
                    cache.position.claimPriceLast
            );
        }
        return (params.amount, state);
    }

    function update(
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.PoolState memory pool,
        CoverPoolStructs.UpdateParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) internal returns (
            CoverPoolStructs.GlobalState memory,
            CoverPoolStructs.PoolState memory,
            int24
        )
    {
        CoverPoolStructs.UpdatePositionCache memory cache;
        (
            params,
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
            return (state, pool, params.claim);

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
                constants,
                params.zeroForOne ? params.lower : params.claim,
                params.zeroForOne ? params.claim : params.upper,
                params.amount,
                params.zeroForOne,
                cache.removeLower,
                cache.removeUpper
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
                cache.position.liquidity = 0;
            }
            delete positions[params.positionId];
        }
        // clear position values
        if (cache.position.liquidity == 0) {
            cache.position.owner = address(0);
            cache.position.lower = 0;
            cache.position.upper = 0;
            cache.position.accumEpochLast = 0;
            cache.position.claimPriceLast = 0;
        }
        // update position bounds
        if (params.zeroForOne) {
            cache.position.upper = params.claim;
        } else {
            cache.position.lower = params.claim;
        }
        positions[params.positionId] = cache.position;
        
        emit Burn(
            params.to,
            params.positionId,
            params.claim,
            params.zeroForOne,
            params.amount,
            cache.position.amountIn,
            cache.finalDeltas.amountOutDelta,
            cache.position.amountOut - cache.finalDeltas.amountOutDelta,
            uint128(cache.amountInFilledMax),
            uint128(cache.amountOutUnfilledMax),
            cache.finalDeltas.amountInDeltaMax,
            cache.finalDeltas.amountOutDeltaMax,
            cache.position.claimPriceLast
        );
        // return cached position in memory and transfer out
        return (state, pool, params.claim);
    }

    function snapshot(
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.PoolState memory pool,
        CoverPoolStructs.UpdateParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) external view returns (
        CoverPoolStructs.CoverPosition memory
    ) {
        CoverPoolStructs.UpdatePositionCache memory cache;
        (
            params,
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
                        ? ConstantProduct.getDx(params.amount, cache.priceLower, cache.priceUpper, false)
                        : ConstantProduct.getDy(params.amount, cache.priceLower, cache.priceUpper, false)
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
        if (percent > 1e38) require (false, 'InvalidBurnPercentage()');
        if (liquidity == 0 && percent > 0) require (false, 'NotEnoughPositionLiquidity()');
        return uint128(uint256(liquidity) * uint256(percent) / 1e38);
    }

    function _deltas(
        mapping(uint256 => CoverPoolStructs.CoverPosition)
            storage positions,
        mapping(int24 => CoverPoolStructs.Tick) storage ticks,
        CoverPoolStructs.TickMap storage tickMap,
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.PoolState memory pool,
        CoverPoolStructs.UpdateParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) internal view returns (
        CoverPoolStructs.UpdateParams memory,
        CoverPoolStructs.UpdatePositionCache memory,
        CoverPoolStructs.GlobalState memory
    ) {
        CoverPoolStructs.UpdatePositionCache memory cache;
        cache.position = positions[params.positionId];
        params.lower = cache.position.lower;
        params.upper = cache.position.upper;
        cache = CoverPoolStructs.UpdatePositionCache({
            position: cache.position,
            pool: pool,
            priceLower: ConstantProduct.getPriceAtTick(params.lower, constants),
            priceClaim: ConstantProduct.getPriceAtTick(params.claim, constants),
            priceUpper: ConstantProduct.getPriceAtTick(params.upper, constants),
            priceSpread: 0,
            amountInFilledMax: 0,
            amountOutUnfilledMax: 0,
            claimTick: ticks[params.claim],
            finalTick: ticks[params.zeroForOne ? params.lower : params.upper],
            earlyReturn: false,
            removeLower: true,
            removeUpper: true,
            deltas: CoverPoolStructs.Deltas(0,0,0,0),
            finalDeltas: CoverPoolStructs.Deltas(0,0,0,0)
        });
        if (params.claim == (params.zeroForOne ? params.lower : params.upper)) {
            params.amount = 1e38;
        }
        params.amount = _convert(cache.position.liquidity, params.amount);

        // check claim is valid
        (params, cache) = Claims.validate(
            tickMap,
            state,
            cache.pool,
            params,
            cache,
            constants
        );
        if (cache.earlyReturn) {
            return (params, cache, state);
        }
        cache.priceSpread = ConstantProduct.getPriceAtTick(params.zeroForOne ? params.claim - constants.tickSpread 
                                                                             : params.claim + constants.tickSpread,
                                                           constants);
        if (params.amount > 0)
            _size(
                CoverPoolStructs.SizeParams(
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

        return (params, cache, state);
    }

    function _size(
        CoverPoolStructs.SizeParams memory params,
        CoverPoolStructs.Immutables memory constants
    ) internal pure  
    {
        // early return if 100% of position burned
        if (constants.minAmountPerAuction == 0) return;
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
            uint128 amount = uint128(ConstantProduct.getDx(
                params.liquidityAmount,
                params.priceLower,
                params.priceUpper,
                false
            ));
            if (denomTokenIn) {
                if (amount / params.auctionCount < minAmountPerAuction)
                    require (false, 'PositionAuctionAmountTooSmall()');
            } else {
                // denominate in incoming token
                uint256 priceAverage = (params.priceUpper + params.priceLower) / 2;
                uint256 convertedAmount = amount * priceAverage / Q96 
                                                 * priceAverage / Q96; // convert by squaring price
                if (convertedAmount / params.auctionCount < minAmountPerAuction) 
                    require (false, 'PositionAuctionAmountTooSmall()');
            }
        } else {
            uint128 amount = uint128(ConstantProduct.getDy(
                params.liquidityAmount,
                params.priceLower,
                params.priceUpper,
                false
            ));
            if (denomTokenIn) {
                // denominate in token1
                // calculate amount in position currently
                if (amount / params.auctionCount < minAmountPerAuction) 
                    require (false, 'PositionAuctionAmountTooSmall()');
            } else {
                // denominate in token0
                uint256 priceAverage = (params.priceUpper + params.priceLower) / 2;
                uint256 convertedAmount = amount * Q96 / priceAverage 
                                                 * Q96 / priceAverage; // convert by squaring price
                if (convertedAmount / params.auctionCount < minAmountPerAuction) 
                    require (false, 'PositionAuctionAmountTooSmall()');
            }
        }
    }

    function _checkpoint(
        CoverPoolStructs.GlobalState memory state,
        CoverPoolStructs.PoolState memory pool,
        CoverPoolStructs.UpdateParams memory params,
        CoverPoolStructs.Immutables memory constants,
        CoverPoolStructs.UpdatePositionCache memory cache
    ) internal pure returns (
        CoverPoolStructs.UpdatePositionCache memory,
        CoverPoolStructs.UpdateParams memory
    ) {
        // update claimPriceLast
        cache.priceClaim = ConstantProduct.getPriceAtTick(params.claim, constants);
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
