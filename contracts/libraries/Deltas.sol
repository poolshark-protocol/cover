// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import '../interfaces/structs/CoverPoolStructs.sol';
import './math/ConstantProduct.sol';

library Deltas {

    function max(
        uint128 liquidity,
        uint160 priceStart,
        uint160 priceEnd,
        bool   isPool0
    ) public pure returns (
        uint128 amountInDeltaMax,
        uint128 amountOutDeltaMax
    ) {
        amountInDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDy(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
                : ConstantProduct.getDx(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
        );
        amountOutDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDx(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
                : ConstantProduct.getDy(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
        );
    }

    function maxRoundUp(
        uint128 liquidity,
        uint160 priceStart,
        uint160 priceEnd,
        bool   isPool0
    ) public pure returns (
        uint128 amountInDeltaMax,
        uint128 amountOutDeltaMax
    ) {
        amountInDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDy(
                    liquidity,
                    priceEnd,
                    priceStart,
                    true
                )
                : ConstantProduct.getDx(
                    liquidity,
                    priceStart,
                    priceEnd,
                    true
                )
        );
        amountOutDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDx(
                    liquidity,
                    priceEnd,
                    priceStart,
                    true
                )
                : ConstantProduct.getDy(
                    liquidity,
                    priceStart,
                    priceEnd,
                    true
                )
        );
    }

    function maxAuction(
        uint128 liquidity,
        uint160 priceStart,
        uint160 priceEnd,
        bool isPool0
    ) public pure returns (
        uint128 amountInDeltaMax,
        uint128 amountOutDeltaMax
    ) {
        amountInDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDy(
                    liquidity,
                    priceStart,
                    priceEnd,
                    true
                )
                : ConstantProduct.getDx(
                    liquidity,
                    priceEnd,
                    priceStart,
                    true
                )
        );
        amountOutDeltaMax = uint128(
            isPool0
                ? ConstantProduct.getDx(
                    liquidity,
                    priceStart,
                    priceEnd,
                    true
                )
                : ConstantProduct.getDy(
                    liquidity,
                    priceEnd,
                    priceStart,
                    true
                )
        );
    }

    function transfer(
        CoverPoolStructs.Deltas memory fromDeltas,
        CoverPoolStructs.Deltas memory toDeltas,
        uint256 percentInTransfer,
        uint256 percentOutTransfer
    ) external pure returns (
        CoverPoolStructs.Deltas memory,
        CoverPoolStructs.Deltas memory
    ) {
        {
            uint128 amountInDeltaChange = uint128(uint256(fromDeltas.amountInDelta) * percentInTransfer / 1e38);
            if (amountInDeltaChange < fromDeltas.amountInDelta ) {
                fromDeltas.amountInDelta -= amountInDeltaChange;
                toDeltas.amountInDelta += amountInDeltaChange;
            } else {
                toDeltas.amountInDelta += fromDeltas.amountInDelta;
                fromDeltas.amountInDelta = 0;
            }
        }
        {
            uint128 amountOutDeltaChange = uint128(uint256(fromDeltas.amountOutDelta) * percentOutTransfer / 1e38);
            if (amountOutDeltaChange < fromDeltas.amountOutDelta ) {
                fromDeltas.amountOutDelta -= amountOutDeltaChange;
                toDeltas.amountOutDelta += amountOutDeltaChange;
            } else {
                toDeltas.amountOutDelta += fromDeltas.amountOutDelta;
                fromDeltas.amountOutDelta = 0;
            }
        }
        return (fromDeltas, toDeltas);
    }

    function transferMax(
        CoverPoolStructs.Deltas memory fromDeltas,
        CoverPoolStructs.Deltas memory toDeltas,
        uint256 percentInTransfer,
        uint256 percentOutTransfer
    ) external pure returns (
        CoverPoolStructs.Deltas memory,
        CoverPoolStructs.Deltas memory
    ) {
        {
            uint128 amountInDeltaMaxChange = uint128(uint256(fromDeltas.amountInDeltaMax) * percentInTransfer / 1e38);
            if (fromDeltas.amountInDeltaMax > amountInDeltaMaxChange) {
                fromDeltas.amountInDeltaMax -= amountInDeltaMaxChange;
                toDeltas.amountInDeltaMax += amountInDeltaMaxChange;
            } else {
                toDeltas.amountInDeltaMax += fromDeltas.amountInDeltaMax;
                fromDeltas.amountInDeltaMax = 0;
            }
        }
        {
            uint128 amountOutDeltaMaxChange = uint128(uint256(fromDeltas.amountOutDeltaMax) * percentOutTransfer / 1e38);
            if (fromDeltas.amountOutDeltaMax > amountOutDeltaMaxChange) {
                fromDeltas.amountOutDeltaMax -= amountOutDeltaMaxChange;
                toDeltas.amountOutDeltaMax   += amountOutDeltaMaxChange;
            } else {
                toDeltas.amountOutDeltaMax += fromDeltas.amountOutDeltaMax;
                fromDeltas.amountOutDeltaMax = 0;
            }
        }
        return (fromDeltas, toDeltas);
    }

    function burnMaxCache(
        CoverPoolStructs.Deltas memory fromDeltas,
        CoverPoolStructs.Tick memory burnTick
    ) external pure returns (
        CoverPoolStructs.Deltas memory
    ) {
        fromDeltas.amountInDeltaMax -= (fromDeltas.amountInDeltaMax 
                                         < burnTick.amountInDeltaMaxMinus) ? fromDeltas.amountInDeltaMax
                                                                           : burnTick.amountInDeltaMaxMinus;
        if (fromDeltas.amountInDeltaMax == 1) {
            fromDeltas.amountInDeltaMax = 0; // handle rounding issues
        }
        fromDeltas.amountOutDeltaMax -= (fromDeltas.amountOutDeltaMax 
                                          < burnTick.amountOutDeltaMaxMinus) ? fromDeltas.amountOutDeltaMax
                                                                             : burnTick.amountOutDeltaMaxMinus;
        return fromDeltas;
    }

    function burnMaxMinus(
        CoverPoolStructs.Tick memory fromTick,
        CoverPoolStructs.Deltas memory burnDeltas
    ) external pure returns (
        CoverPoolStructs.Tick memory
    ) {
        fromTick.amountInDeltaMaxMinus -= (fromTick.amountInDeltaMaxMinus
                                            < burnDeltas.amountInDeltaMax) ? fromTick.amountInDeltaMaxMinus
                                                                           : burnDeltas.amountInDeltaMax;
        if (fromTick.amountInDeltaMaxMinus == 1) {
            fromTick.amountInDeltaMaxMinus = 0; // handle rounding issues
        }
        fromTick.amountOutDeltaMaxMinus -= (fromTick.amountOutDeltaMaxMinus 
                                             < burnDeltas.amountOutDeltaMax) ? fromTick.amountOutDeltaMaxMinus
                                                                                  : burnDeltas.amountOutDeltaMax;
        return fromTick;
    }

    function burnMaxPool(
        CoverPoolStructs.PoolState memory pool,
        CoverPoolStructs.UpdatePositionCache memory cache,
        CoverPoolStructs.UpdateParams memory params
    ) external pure returns (
        CoverPoolStructs.PoolState memory
    )
    {
        uint128 amountInMaxClaimedBefore; uint128 amountOutMaxClaimedBefore;
        (
            amountInMaxClaimedBefore,
            amountOutMaxClaimedBefore
        ) = maxAuction(
            params.amount,
            cache.priceSpread,
            cache.position.claimPriceLast,
            params.zeroForOne
        );
        pool.amountInDeltaMaxClaimed  -= pool.amountInDeltaMaxClaimed > amountInMaxClaimedBefore ? amountInMaxClaimedBefore
                                                                                                 : pool.amountInDeltaMaxClaimed;
        pool.amountOutDeltaMaxClaimed -= pool.amountOutDeltaMaxClaimed > amountOutMaxClaimedBefore ? amountOutMaxClaimedBefore
                                                                                                   : pool.amountOutDeltaMaxClaimed;
        return pool;
    }

    struct FromLocals {
        CoverPoolStructs.Deltas fromDeltas;
        uint256 percentOnTick;
        uint128 amountInDeltaChange;
        uint128 amountOutDeltaChange;
    }

    function from(
        CoverPoolStructs.Tick memory fromTick,
        CoverPoolStructs.Deltas memory toDeltas,
        bool isPool0
    ) external pure returns (
        CoverPoolStructs.Tick memory,
        CoverPoolStructs.Deltas memory
    ) {
        FromLocals memory locals;
        locals.fromDeltas = isPool0 ? fromTick.deltas0 
                                    : fromTick.deltas1;
        locals.percentOnTick = uint256(locals.fromDeltas.amountInDeltaMax) * 1e38 / (uint256(locals.fromDeltas.amountInDeltaMax) + uint256(fromTick.amountInDeltaMaxStashed));
        {
            locals.amountInDeltaChange = uint128(uint256(locals.fromDeltas.amountInDelta) * locals.percentOnTick / 1e38);
            locals.fromDeltas.amountInDelta -= locals.amountInDeltaChange;
            toDeltas.amountInDelta += locals.amountInDeltaChange;
            toDeltas.amountInDeltaMax += locals.fromDeltas.amountInDeltaMax;
            locals.fromDeltas.amountInDeltaMax = 0;
        }
        locals.percentOnTick = uint256(locals.fromDeltas.amountOutDeltaMax) * 1e38 / (uint256(locals.fromDeltas.amountOutDeltaMax) + uint256(fromTick.amountOutDeltaMaxStashed));
        {
            locals.amountOutDeltaChange = uint128(uint256(locals.fromDeltas.amountOutDelta) * locals.percentOnTick / 1e38);
            locals.fromDeltas.amountOutDelta -= locals.amountOutDeltaChange;
            toDeltas.amountOutDelta += locals.amountOutDeltaChange;
            toDeltas.amountOutDeltaMax += locals.fromDeltas.amountOutDeltaMax;
            locals.fromDeltas.amountOutDeltaMax = 0;
        }
        if (isPool0) {
            fromTick.deltas0 = locals.fromDeltas;
        } else {
            fromTick.deltas1 = locals.fromDeltas;
        }
        return (fromTick, toDeltas);
    }

    function to(
        CoverPoolStructs.Deltas memory fromDeltas,
        CoverPoolStructs.Tick memory toTick,
        bool isPool0
    ) external pure returns (
        CoverPoolStructs.Deltas memory,
        CoverPoolStructs.Tick memory
    ) {
        CoverPoolStructs.Deltas memory toDeltas = isPool0 ? toTick.deltas0 
                                                          : toTick.deltas1;
        toDeltas.amountInDelta     += fromDeltas.amountInDelta;
        toDeltas.amountInDeltaMax  += fromDeltas.amountInDeltaMax;
        toDeltas.amountOutDelta    += fromDeltas.amountOutDelta;
        toDeltas.amountOutDeltaMax += fromDeltas.amountOutDeltaMax;
        if (isPool0) {
            toTick.deltas0 = toDeltas;
        } else {
            toTick.deltas1 = toDeltas;
        }
        fromDeltas = CoverPoolStructs.Deltas(0,0,0,0);
        return (fromDeltas, toTick);
    }

    function stash(
        CoverPoolStructs.Deltas memory fromDeltas,
        CoverPoolStructs.Tick memory toTick,
        bool isPool0
    ) external pure returns (
        CoverPoolStructs.Deltas memory,
        CoverPoolStructs.Tick memory
    ) {
        CoverPoolStructs.Deltas memory toDeltas = isPool0 ? toTick.deltas0 
                                                          : toTick.deltas1;
        // store deltas on tick
        toDeltas.amountInDelta     += fromDeltas.amountInDelta;
        toDeltas.amountOutDelta    += fromDeltas.amountOutDelta;
        // store delta maxes on stashed deltas
        toTick.amountInDeltaMaxStashed  += fromDeltas.amountInDeltaMax;
        toTick.amountOutDeltaMaxStashed += fromDeltas.amountOutDeltaMax;
        if (isPool0) {
            toTick.deltas0 = toDeltas;
        } else {
            toTick.deltas1 = toDeltas;
        }
        fromDeltas = CoverPoolStructs.Deltas(0,0,0,0);
        return (fromDeltas, toTick);
    }

    struct UnstashLocals {
        CoverPoolStructs.Deltas fromDeltas;
        uint256 totalDeltaMax;
        uint256 percentStashed;
        uint128 amountInDeltaChange;
        uint128 amountOutDeltaChange;
    }

    function unstash(
        CoverPoolStructs.Tick memory fromTick,
        CoverPoolStructs.Deltas memory toDeltas,
        bool isPool0
    ) external pure returns (
        CoverPoolStructs.Tick memory,
        CoverPoolStructs.Deltas memory
    ) {
        toDeltas.amountInDeltaMax  += fromTick.amountInDeltaMaxStashed;
        toDeltas.amountOutDeltaMax += fromTick.amountOutDeltaMaxStashed;

        UnstashLocals memory locals;
        locals.fromDeltas = isPool0 ? fromTick.deltas0 : fromTick.deltas1;
        locals.totalDeltaMax = uint256(fromTick.amountInDeltaMaxStashed) + uint256(locals.fromDeltas.amountInDeltaMax);
        
        if (locals.totalDeltaMax > 0) {
            uint256 percentStashed = uint256(fromTick.amountInDeltaMaxStashed) * 1e38 / locals.totalDeltaMax;
            uint128 amountInDeltaChange = uint128(uint256(locals.fromDeltas.amountInDelta) * percentStashed / 1e38);
            locals.fromDeltas.amountInDelta -= amountInDeltaChange;
            toDeltas.amountInDelta += amountInDeltaChange;
        }
        
        locals.totalDeltaMax = uint256(fromTick.amountOutDeltaMaxStashed) + uint256(locals.fromDeltas.amountOutDeltaMax);
        
        if (locals.totalDeltaMax > 0) {
            uint256 percentStashed = uint256(fromTick.amountOutDeltaMaxStashed) * 1e38 / locals.totalDeltaMax;
            uint128 amountOutDeltaChange = uint128(uint256(locals.fromDeltas.amountOutDelta) * percentStashed / 1e38);
            locals.fromDeltas.amountOutDelta -= amountOutDeltaChange;
            toDeltas.amountOutDelta += amountOutDeltaChange;
        }
        if (isPool0) {
            fromTick.deltas0 = locals.fromDeltas;
        } else {
            fromTick.deltas1 = locals.fromDeltas;
        }
        fromTick.amountInDeltaMaxStashed = 0;
        fromTick.amountOutDeltaMaxStashed = 0;
        return (fromTick, toDeltas);
    }

    function update(
        CoverPoolStructs.Tick memory tick,
        uint128 amount,
        uint160 priceLower,
        uint160 priceUpper,
        bool   isPool0,
        bool   isAdded
    ) external pure returns (
        CoverPoolStructs.Tick memory,
        CoverPoolStructs.Deltas memory
    ) {
        // update max deltas
        uint128 amountInDeltaMax; uint128 amountOutDeltaMax;
        if (isPool0) {
            (
                amountInDeltaMax,
                amountOutDeltaMax
            ) = max(amount, priceUpper, priceLower, true);
        } else {
            (
                amountInDeltaMax,
                amountOutDeltaMax
            ) = max(amount, priceLower, priceUpper, false);
        }
        if (isAdded) {
            tick.amountInDeltaMaxMinus  += amountInDeltaMax;
            tick.amountOutDeltaMaxMinus += amountOutDeltaMax;
        } else {
            tick.amountInDeltaMaxMinus  -= tick.amountInDeltaMaxMinus  > amountInDeltaMax ? amountInDeltaMax
                                                                                          : tick.amountInDeltaMaxMinus;
            tick.amountOutDeltaMaxMinus -= tick.amountOutDeltaMaxMinus > amountOutDeltaMax ? amountOutDeltaMax                                                                           : tick.amountOutDeltaMaxMinus;
        }
        return (tick, CoverPoolStructs.Deltas(0,0,amountInDeltaMax, amountOutDeltaMax));
    }
}