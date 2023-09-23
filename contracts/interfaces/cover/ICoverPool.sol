// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../structs/CoverPoolStructs.sol';
import '../structs/PoolsharkStructs.sol';

/**
 * @title ICoverPool
 * @author Poolshark
 * @notice Defines the basic interface for a Cover Pool.
 */
interface ICoverPool is CoverPoolStructs {
    

    /**
     * @notice Deposits `amountIn` of asset to be auctioned off each time price range is crossed further into.
     * - E.g. User supplies 1 WETH in the range 1500 USDC per WETH to 1400 USDC per WETH
              As latestTick crosses from 1500 USDC per WETH to 1400 USDC per WETH,
              the user's liquidity within each tick spacing is auctioned off.
     * @dev The position will be shrunk onto the correct side of latestTick.
     * @dev The position will be minted with the `to` address as the owner.
     * @param params The parameters for the function. See MintCoverParams.
     */
    function mint(
        MintCoverParams memory params
    ) external;



    /**
     * @notice Withdraws the input token and returns any filled and/or unfilled amounts to the 'to' address specified. 
     * - E.g. User supplies 1 WETH in the range 1500 USDC per WETH to 1400 USDC per WETH
              As latestTick crosses from 1500 USDC per WETH to 1400 USDC per WETH,
              the user's liquidity within each tick spacing is auctioned off.
     * @dev The position will be shrunk based on the claim tick passed.
     * @dev The position amounts will be returned to the `to` address specified.
     * @dev The `sync` flag can be set to false so users can exit safely without syncing latestTick.
     * @param params The parameters for the function. See BurnCoverParams.
     */
    function burn(
        BurnCoverParams memory params
    ) external; 

    /**
     * @notice Swaps `tokenIn` for `tokenOut`. 
               `tokenIn` will be `token0` if `zeroForOne` is true.
               `tokenIn` will be `token1` if `zeroForOne` is false.
               The pool price represents token1 per token0.
               The pool price will decrease if `zeroForOne` is true.
               The pool price will increase if `zeroForOne` is false. 
     * @param params The parameters for the function. See SwapParams.
     * @return amount0Delta The amount of token0 spent (negative) or received (positive) by the user
     * @return amount1Delta The amount of token1 spent (negative) or received (positive) by the user
     */
    function swap(
        SwapParams memory params
    ) external returns (
        int256 amount0Delta,
        int256 amount1Delta
    );

    /**
     * @notice Quotes the amount of `tokenIn` for `tokenOut`. 
               `tokenIn` will be `token0` if `zeroForOne` is true.
               `tokenIn` will be `token1` if `zeroForOne` is false.
               The pool price represents token1 per token0.
               The pool price will decrease if `zeroForOne` is true.
               The pool price will increase if `zeroForOne` is false. 
     * @param params The parameters for the function. See SwapParams above.
     * @return inAmount  The amount of tokenIn to be spent
     * @return outAmount The amount of tokenOut to be received
     * @return priceAfter The Q64.96 square root price after the swap
     */
    function quote(
        QuoteParams memory params
    ) external view returns (
        int256 inAmount,
        int256 outAmount,
        uint256 priceAfter
    );



    /**
     * @notice Snapshots the current state of an existing position. 
     * @param params The parameters for the function. See SwapParams above.
     * @return position The updated position containing `amountIn` and `amountOut`
     * @dev positions amounts reflected will be collected by the user if `burn` is called
     */
    function snapshot(
        SnapshotCoverParams memory params
    ) external view returns (
        CoverPosition memory position
    );

    /**
     * @notice Sets and collect protocol fees from the pool. 
     * @param syncFee The new syncFee to be set if `setFees` is true.
     * @param fillFee The new fillFee to be set if `setFees` is true.
     * @return token0Fees The `token0` fees collected.
     * @return token1Fees The `token1` fees collected.
     * @dev `syncFee` is a basis point fee to be paid to users who sync latestTick
     * @dev `fillFee` is a basis point fee to be paid to the protocol for amounts filled
     * @dev All fees are zero by default unless the protocol decides to enable them.
     */
    function fees(
        uint16 syncFee,
        uint16 fillFee,
        bool setFees
    ) external returns (
        uint128 token0Fees,
        uint128 token1Fees
    );

    function immutables(
    ) external view returns (
        CoverImmutables memory constants
    );

    function priceBounds(
        int16 tickSpacing
    ) external pure returns (
        uint160 minPrice,
        uint160 maxPrice
    );
}
