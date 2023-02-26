// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './DyDxMath.sol';
import '../interfaces/ICoverPoolStructs.sol';

//TODO: stash and unstash
//TODO: transfer delta maxes as well in Positions.update()
library Deltas {
    function transfer(
        ICoverPoolStructs.Deltas memory fromDeltas,
        ICoverPoolStructs.Deltas memory toDeltas,
        uint256 percentInTransfer,
        uint256 percentOutTransfer
    ) external pure returns (
        ICoverPoolStructs.Deltas memory,
        ICoverPoolStructs.Deltas memory
    ) {
        {
            uint128 amountInDeltaChange = uint128(uint256(fromDeltas.amountInDelta) * percentInTransfer / 1e38);
            fromDeltas.amountInDelta -= amountInDeltaChange;
            toDeltas.amountInDelta += amountInDeltaChange;
        }
        {
            uint128 amountOutDeltaChange = uint128(uint256(fromDeltas.amountOutDelta) * percentOutTransfer / 1e38);
            fromDeltas.amountOutDelta -= amountOutDeltaChange;
            toDeltas.amountOutDelta += amountOutDeltaChange;
        }
        return (fromDeltas, toDeltas);
    }

    function burn(
        ICoverPoolStructs.Deltas memory fromDeltas,
        ICoverPoolStructs.Deltas memory burnDeltas,
        bool maxOnly
    ) external pure returns (
        ICoverPoolStructs.Deltas memory
    ) {
        if(!maxOnly) {
            fromDeltas.amountInDelta     -= burnDeltas.amountInDelta;
            fromDeltas.amountOutDelta    -= burnDeltas.amountOutDelta;
        }
        fromDeltas.amountInDeltaMax  -= burnDeltas.amountInDeltaMax;
        fromDeltas.amountOutDeltaMax -= burnDeltas.amountOutDeltaMax;
        return fromDeltas;
    }

    function stash(
        ICoverPoolStructs.Deltas memory fromDeltas,
        ICoverPoolStructs.Tick memory toTick,
        uint256 stashPercent
    ) external pure returns (
        ICoverPoolStructs.Deltas memory,
        ICoverPoolStructs.Deltas memory
    ) {

    }

    function unstash(
        ICoverPoolStructs.Tick memory fromTick,
        ICoverPoolStructs.Deltas memory toDeltas,
        uint256 stashPercent
    ) external pure returns (
        ICoverPoolStructs.Deltas memory,
        ICoverPoolStructs.Deltas memory
    ) {

    }

    function max(
        uint128 liquidity,
        uint160 priceStart,
        uint160 priceEnd,
        bool   isPool0
    ) external pure returns (
        uint128 amountInDeltaMax,
        uint128 amountOutDeltaMax
    ) {
        amountInDeltaMax = uint128(
            isPool0
                ? DyDxMath.getDy(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
                : DyDxMath.getDx(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
        );
        amountOutDeltaMax = uint128(
            isPool0
                ? DyDxMath.getDx(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
                : DyDxMath.getDy(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
        );
    }

    function maxAuction(
        uint128 liquidity,
        uint160 priceStart,
        uint160 priceEnd,
        bool isPool0
    ) external pure returns (
        uint128 amountInDeltaMax,
        uint128 amountOutDeltaMax
    ) {
        amountInDeltaMax = uint128(
            isPool0
                ? DyDxMath.getDy(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
                : DyDxMath.getDx(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
        );
        amountOutDeltaMax = uint128(
            isPool0
                ? DyDxMath.getDx(
                    liquidity,
                    priceStart,
                    priceEnd,
                    false
                )
                : DyDxMath.getDy(
                    liquidity,
                    priceEnd,
                    priceStart,
                    false
                )
        );
    }
}