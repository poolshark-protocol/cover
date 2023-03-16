// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import './interfaces/ICoverPool.sol';
import './interfaces/ICoverPoolStructs.sol';

contract CoverPoolRouter is ICoverPoolStructs
{
    struct PoolParams {
        address pool; /// @ dev - skips factory call
        address fromToken;
        address destToken;
        uint16  tickSpread;
        uint16  twapLength;
        uint16  auctionLength;
    }

    function mint(
        address pool,
        MintParams calldata mintParams
    ) external {
        MintParams memory params = mintParams;
        ICoverPool(pool).mint(params); 
    }

    function burn(
        address pool,
        BurnParams calldata burnParams
    ) external {
        BurnParams memory params = burnParams;
        ICoverPool(pool).burn(params);
    }
}
