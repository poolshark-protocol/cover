// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import '../../interfaces/structs/CoverPoolStructs.sol';
import '../../libraries/math/ConstantProduct.sol';

library EchidnaAssertions {

    event LiquidityGlobalUnderflow(uint128 liquidityGlobal, uint128 amount, string location);
    event LiquidityUnderflow(uint128 liquidity, uint128 amount, string location);
    event LiquidityOverflow(uint128 liquidity, uint128 amount, string location);
    event LiquidityUnlock(int128 liquidity);
    event PoolBalanceExceeded(uint256 poolBalance, uint256 outputAmount);
    event LiquidityDelta(int128 liquidityDelta);
    event TickDivisibleByTickSpacing(int24 tick, int16 tickSpacing);
    event TickWithinBounds(int24 tick, int24 minTick, int24 maxTick);
    event InfiniteLoop0(int24 accumTick, int24 crossTick);
    event InfiniteLoop1(int24 accumTick, int24 crossTick);

    function assertLiquidityGlobalUnderflows(uint128 liquidityGlobal, uint128 amount, string memory location) internal {
        emit LiquidityGlobalUnderflow(liquidityGlobal, amount, location);
        assert(liquidityGlobal >= amount);
    }

    function assertLiquidityUnderflows(uint128 liquidity, uint128 amount, string memory location) internal {
        emit LiquidityUnderflow(liquidity, amount, location);
        assert(liquidity >= amount);
    }

    function assertLiquidityOverflows(uint128 liquidity, uint128 amount, string memory location) internal {
        emit LiquidityUnderflow(liquidity, amount, location);
        assert(uint256(liquidity) + uint256(amount) <= uint128(type(int128).max));
    }

    function assertAmountInDeltaMaxMinusUnderflows(uint128 liquidityAbs, uint128 amount, string memory location) internal {
        emit LiquidityUnderflow(liquidityAbs, amount, location);
        assert(liquidityAbs >= amount);
    }

    function assertAmountOutDeltaMaxMinusUnderflows(uint128 liquidityAbs, uint128 amount, string memory location) internal {
        emit LiquidityUnderflow(liquidityAbs, amount, location);
        assert(liquidityAbs >= amount);
    }

    function assertPositiveLiquidityOnUnlock(int128 liquidity) internal {
        emit LiquidityUnlock(liquidity);
        assert(liquidity >= 0);
    }

    function assertPoolBalanceExceeded(uint256 poolBalance, uint256 outputAmount) internal {
        emit PoolBalanceExceeded(poolBalance, outputAmount);
        assert(poolBalance >= outputAmount);
    }

    function assertTickDivisibleByTickSpacing(int24 tick, int16 tickSpacing) internal {
        emit TickDivisibleByTickSpacing(tick, tickSpacing);
        assert(tick % tickSpacing == 0);
    }

    function assertTickWithinBounds(int24 tick, int24 minTick, int24 maxTick) internal {
        emit TickWithinBounds(tick, minTick, maxTick);
        assert(tick >= minTick);
        assert(tick <= maxTick);
    }

    function assertInfiniteLoop0(int24 accumTick, int24 crossTick, int24 minTick) internal {
        emit InfiniteLoop0(accumTick, crossTick);
        assert(accumTick < crossTick || (accumTick == crossTick && accumTick == minTick));
    }

    function assertInfiniteLoop1(int24 accumTick, int24 crossTick, int24 maxTick) internal {
        emit InfiniteLoop1(accumTick, crossTick);
        assert(accumTick > crossTick || (accumTick == crossTick && accumTick == maxTick));
    }
}