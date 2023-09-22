// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../structs/PoolsharkStructs.sol';

interface ILimitPool is PoolsharkStructs {
    function initialize(
        uint160 startPrice
    ) external;

    function mintLimit(
        MintLimitParams memory params
    ) external;

    function burnLimit(
        BurnLimitParams memory params
    ) external;

    function immutables(
    ) external view returns(
        LimitImmutables memory
    );

    function priceBounds(
        int16 tickSpacing
    ) external pure returns (
        uint160 minPrice,
        uint160 maxPrice
    );
}
