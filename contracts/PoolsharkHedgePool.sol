// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

//TODO: deploy library code once and reference from factory
// have interfaces for library contracts
import "./interfaces/IPoolsharkHedgePool.sol";
import "./interfaces/IConcentratedPool.sol";
import "./base/PoolsharkHedgePoolStorage.sol";
import "./base/PoolsharkHedgePoolEvents.sol";
import "./utils/SafeTransfers.sol";
import "./utils/PoolsharkErrors.sol";
import "hardhat/console.sol";

/// @notice Poolshark Directional Liquidity pool implementation.
/// @dev SafeTransfers contains PoolsharkHedgePoolErrors
contract PoolsharkHedgePool is
    IPoolsharkHedgePool,
    PoolsharkHedgePoolStorage,
    PoolsharkHedgePoolEvents,
    PoolsharkTicksErrors,
    PoolsharkMiscErrors,
    PoolsharkPositionErrors,
    SafeTransfers
{
    int24 internal immutable tickSpacing;
    uint24 internal immutable swapFee; /// @dev Fee measured in basis points (.e.g 1000 = 0.1%).
    uint128 internal immutable MAX_TICK_LIQUIDITY;

    address internal immutable factory;
    address internal immutable token0;
    address internal immutable token1;

    IConcentratedPool internal immutable inputPool;

    modifier lock() {
        if (unlocked == 2) revert Locked();
        unlocked = 2;
        _;
        unlocked = 1;
    }

    constructor(
        address _inputPool,
        address _libraries,
        uint24  _swapFee, 
        int24  _tickSpacing
    ) {
        // check for invalid params
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = msg.sender;
        inputPool   = IConcentratedPool(_inputPool);
        utils       = IPoolsharkUtils(_libraries);
        token0      = IConcentratedPool(inputPool).token0();
        token1      = IConcentratedPool(inputPool).token1();
        swapFee     = _swapFee;
        //TODO: should be 1% for .1% spacing on inputPool
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(factory).owner();
        MAX_TICK_LIQUIDITY = Ticks.getMaxLiquidity(_tickSpacing);

        // set default initial values
        //TODO: insertSingle or pass MAX_TICK as upper
        // @dev increase pool observations if not sufficient
        latestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        if (latestTick >= TickMath.MIN_TICK) {
            _initialize();
            unlocked = 1;
            lastBlockNumber = block.number;
        }
    }

    //TODO: test this check
    function _ensureInitialized() internal {
        if (latestTick < TickMath.MIN_TICK) {
            if(utils.isPoolObservationsEnough(IConcentratedPool(inputPool))) {
                _initialize();
                unlocked = 1;
                lastBlockNumber = block.number;
            }
            revert WaitUntilEnoughObservations(); 
        }
    }

    function _initialize() internal {
        int24 initLatestTick = utils.initializePoolObservations(IConcentratedPool(inputPool));
        latestTick = initLatestTick / int24(tickSpacing) * int24(tickSpacing);
        Ticks.initialize(
            tickNodes,
            pool0,
            pool1,
            initLatestTick
        );
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function mint(
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        int24 claim,
        uint128 amountDesired,
        bool zeroForOne
    ) external {
        /// @dev - don't allow mints until we have enough observations from inputPool
        _ensureInitialized();
        //TODO: move tick update check here
        if(block.number != lastBlockNumber) {
            lastBlockNumber = block.number;
            //can save a couple 100 gas if we skip this when no update
            (pool0, pool1, latestTick) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                latestTick,
                utils.calculateAverageTick(inputPool),
                tickSpacing
            );
        }
        _validatePosition(lower, upper, zeroForOne, amountDesired);
        //TODO: handle upperOld and lowerOld being invalid
        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(upper));

        uint256 liquidityMinted = DyDxMath.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            zeroForOne ? priceLower : priceUpper,
            zeroForOne ? 0 : uint256(amountDesired),
            zeroForOne ? uint256(amountDesired) : 0
        );
        // handle partial mints
        if (zeroForOne && upper >= latestTick) {
            upper = latestTick - int24(tickSpacing);
            upperOld = latestTick;
            uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(upper);
            amountDesired -= uint128(DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper, false));
            priceUpper = priceNewUpper;
        }
        if (!zeroForOne && lower <= latestTick) {
            lower = latestTick + int24(tickSpacing);
            lowerOld = latestTick;
            uint256 priceNewLower = TickMath.getSqrtRatioAtTick(lower);
            amountDesired -= uint128(DyDxMath.getDy(liquidityMinted, priceLower, priceNewLower, false));
            priceLower = priceNewLower;
        }

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();

        if(zeroForOne){
            _transferIn(token0, amountDesired);
        } else {
            _transferIn(token1, amountDesired);
        }

        unchecked {
            _updatePosition(
                msg.sender,
                lower,
                upper,
                claim,
                zeroForOne,
                int128(uint128(liquidityMinted))
            );
            /// @dev - pool current liquidity should never be increased on mint
        }

        //should remove from old lower if necessary
        //and add liquidity to new ticks
        Ticks.insert(
            zeroForOne ? ticks0 : ticks1,
            tickNodes,
            latestTick,
            lowerOld,
            lower,
            upperOld,
            upper,
            uint128(liquidityMinted),
            zeroForOne
        );

        console.logInt(ticks1[upper].liquidityDelta);

        emit Mint(
            msg.sender,
            lower,
            upper,
            zeroForOne,
            uint128(liquidityMinted)
        );
    }

    function burn(
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne,
        uint128 amount
    )
        public
        lock
    {

        /// @dev - not necessary since position will be empty
        // _ensureInitialized();
        // console.log('zero previous tick:');
        // console.logInt(ticks[0].previousTick);

        if(block.number != lastBlockNumber) {
            // console.log("accumulating last block");
            lastBlockNumber = block.number;
            (pool0, pool1, latestTick) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                latestTick,
                utils.calculateAverageTick(inputPool),
                tickSpacing
            );
        }
        console.log('zero previous tick:');
        console.log('zero previus tick:');
        // console.logInt(ticks[0].previousTick);

        //TODO: burning liquidity should take liquidity out past the current auction
        
        // Ensure no overflow happens when we cast from uint128 to int128.
        if (amount > uint128(type(int128).max)) revert LiquidityOverflow();

        // _updatePosition(msg.sender, lower, upper, -int128(amount));
        _updatePosition(
            msg.sender,
            lower,
            upper,
            claim,
            zeroForOne,
            -int128(amount)
        );
        console.log('zero previous tick:');
        //TODO: get token amounts from _updatePosition return values
        emit Burn(msg.sender, lower, upper, zeroForOne, amount);
    }

    // function collect(int24 lower, int24 upper) public lock returns (uint256 amountInfees, uint256 amountOutfees) {
    //     (amountInfees, amountOutfees) = _updatePosition(
    //                                      msg.sender, 
    //                                      lower, 
    //                                      upper, 
    //                                      0
    //                                  );
    //     // address owner,
    //     // int24 lower,
    //     // int24 upper,
    //     // bool zeroForOne,
    //     // int128 amount,
    //     // bool claiming,
    //     // int24 claim

    //     _transferBothTokens(msg.sender, amountInfees, amountOutfees);

    //     emit Collect(msg.sender, amountInfees, amountOutfees);
    // }

    /// @dev Swaps one token for another. The router must prefund this contract and ensure there isn't too much slippage.
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint160 priceLimit
        // bytes calldata data
    ) external override lock returns (uint256 amountOut) {
        //TODO: is this needed?
        if (latestTick < TickMath.MIN_TICK) revert WaitUntilEnoughObservations();
        PoolState memory pool = zeroForOne ? pool1 : pool0;
        TickMath.validatePrice(priceLimit);

        _transferIn(zeroForOne ? token0 : token1, amountIn);

        if(block.number != lastBlockNumber) {
            lastBlockNumber = block.number;
            // console.log('min latest max');
            // console.logInt(tickNodes[-887272].nextTick);
            // console.logInt(tickNodes[-887272].previousTick);
            (pool0, pool1, latestTick) = Ticks.accumulateLastBlock(
                ticks0,
                ticks1,
                tickNodes,
                pool0,
                pool1,
                latestTick,
                utils.calculateAverageTick(inputPool),
                tickSpacing
            );
        }

        SwapCache memory cache = SwapCache({
            price: pool.price,
            liquidity: pool.liquidity,
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6)
        });

        // console.log('starting tick:');
        // console.logInt(latestTick);
        // console.log("liquidity:", cache.liquidity);

        /// @dev - liquidity range is limited to one tick within latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to latestTick
        uint256 nextTickPrice = zeroForOne ? uint256(TickMath.getSqrtRatioAtTick(latestTick - int24(tickSpacing))) :
                                             uint256(TickMath.getSqrtRatioAtTick(latestTick + int24(tickSpacing))) ;
        uint256 nextPrice = nextTickPrice;
        // console.log("next price:", nextPrice);

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price, false);
            // console.log("max dx:", maxDx);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input)
                );
                if (!(nextPrice <= newPrice && newPrice < cache.price)) {
                    newPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                }
                // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                amountOut = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                // console.log("dtokenOut:", output);
                cache.price= newPrice;
                cache.input = 0;
            } else {
                // Execute swap step and cross the tick.
                // console.log('nextsqrtprice:', nextPrice);
                // console.log('currentprice:', cache.price);
                amountOut = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                // console.log("dtokenOut:", output);
                cache.price= nextPrice;
                cache.input -= maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextTickPrice, false);
            // console.log("max dy:", maxDy);
            if (cache.input <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.liquidity);
                // Calculate output of swap
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                cache.price = newPrice;
                cache.input = 0;
            } else {
                // Swap & cross the tick.
                amountOut = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                cache.price = nextTickPrice;
                cache.input -= maxDy;
            }
        }

        // It increases each swap step.
        // amountOut += output;

        zeroForOne ? pool1.price = uint160(cache.price) : 
                     pool0.price = uint160(cache.price) ;

        if (zeroForOne) {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.feeAmount -= feeReturn;
                pool.feeGrowthGlobalIn += uint232(cache.feeAmount); 
                _transferOut(recipient, token0, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token0, token1, amountIn, amountOut);
        } else {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.feeAmount -= feeReturn;
                pool.feeGrowthGlobalIn += uint232(cache.feeAmount); 
                _transferOut(recipient, token1, cache.input + feeReturn);
            }
            _transferOut(recipient, token1, amountOut);
            emit Swap(recipient, token1, token0, amountIn, amountOut);
        }
    }

    function _validatePosition(int24 lower, int24 upper, bool zeroForOne, uint128 amountDesired) internal view {
        if (lower % int24(tickSpacing) != 0) revert InvalidTick();
        if (upper % int24(tickSpacing) != 0) revert InvalidTick();
        if (amountDesired == 0) revert InvalidPosition();
        if (lower >= upper) revert InvalidPosition();
        if (zeroForOne) {
            if (lower >= latestTick) revert InvalidPosition();
        } else {
            // console.log('upper param');
            // console.logInt(upper);
            // console.logInt(latestTick);
            if (upper <= latestTick) revert InvalidPosition();
        }
    }

    function getAmountIn(
        bool zeroForOne,
        uint256 amountIn,
        uint160 priceLimit
    ) internal view returns (uint256 inAmount, uint256 outAmount) {
        // TODO: make override
        SwapCache memory cache = SwapCache({
            price: zeroForOne ? pool1.price : pool0.price,
            liquidity: zeroForOne ? pool1.liquidity : pool0.liquidity,
            feeAmount: utils.mulDivRoundingUp(amountIn, swapFee, 1e6),
            // currentTick: nearestTick, //TODO: price goes to max latestTick + tickSpacing
            input: amountIn - utils.mulDivRoundingUp(amountIn, swapFee, 1e6)
        });

        // console.log('starting tick:');
        // console.logInt(latestTick);
        // console.log("liquidity:", cache.liquidity);
        /// @dev - liquidity range is limited to one tick within latestTick - should we add tick crossing?
        /// @dev not sure whether to handle greater than tickSpacing range
        /// @dev everything will always be cleared out except for the closest tick to latestTick
        uint256 nextTickPrice = zeroForOne ? uint256(TickMath.getSqrtRatioAtTick(latestTick - int24(tickSpacing))) :
                                             uint256(TickMath.getSqrtRatioAtTick(latestTick + int24(tickSpacing))) ;
        uint256 nextPrice = nextTickPrice;
        // console.log("next price:", nextPrice);

        if (zeroForOne) {
            // Trading token 0 (x) for token 1 (y).
            // price  is decreasing.
            if (nextPrice < priceLimit) { nextPrice = priceLimit; }
            uint256 maxDx = DyDxMath.getDx(cache.liquidity, nextPrice, cache.price, false);
            // console.log("max dx:", maxDx);
            if (cache.input <= maxDx) {
                // We can swap within the current range.
                uint256 liquidityPadded = cache.liquidity << 96;
                // calculate price after swap
                uint256 newPrice = uint256(
                    utils.mulDivRoundingUp(liquidityPadded, cache.price, liquidityPadded + cache.price * cache.input)
                );
                if (!(nextPrice <= newPrice && newPrice < cache.price)) {
                    newPrice = uint160(utils.divRoundingUp(liquidityPadded, liquidityPadded / cache.price + cache.input));
                }
                // Based on the sqrtPricedifference calculate the output of th swap: Δy = Δ√P · L.
                outAmount = DyDxMath.getDy(cache.liquidity, newPrice, cache.price, false);
                inAmount  = amountIn;
                // console.log("dtokenOut:", output);
            } else {
                // Execute swap step and cross the tick.
                // console.log('nextsqrtprice:', nextPrice);
                // console.log('currentprice:', cache.price);
                outAmount = DyDxMath.getDy(cache.liquidity, nextPrice, cache.price, false);
                inAmount = maxDx;
            }
        } else {
            // Price is increasing.
            if (nextPrice > priceLimit) { nextPrice = priceLimit; }
            uint256 maxDy = DyDxMath.getDy(cache.liquidity, cache.price, nextTickPrice, false);
            // console.log("max dy:", maxDy);
            if (cache.input <= maxDy) {
                // We can swap within the current range.
                // Calculate new price after swap: ΔP = Δy/L.
                uint256 newPrice = cache.price +
                    FullPrecisionMath.mulDiv(cache.input, 0x1000000000000000000000000, cache.liquidity);
                // Calculate output of swap
                outAmount = DyDxMath.getDx(cache.liquidity, cache.price, newPrice, false);
                inAmount = amountIn;
            } else {
                // Swap & cross the tick.
                outAmount = DyDxMath.getDx(cache.liquidity, cache.price, nextTickPrice, false);
                inAmount = maxDy;
            }
        }
        if (zeroForOne) {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.input += feeReturn;
            }
        } else {
            if(cache.input > 0) {
                uint128 feeReturn = uint128(
                                            cache.input * 1e18 
                                            / (amountIn - cache.feeAmount) 
                                            * cache.feeAmount / 1e18
                                           );
                cache.input += feeReturn;
            }
        }
        inAmount -= cache.input;

        return (inAmount, outAmount);
    }


    function _transferBothTokens(
        address to,
        uint256 shares0,
        uint256 shares1
    ) internal {
        _transferOut(to, token0, shares0);
        _transferOut(to, token1, shares1);
    }

    //TODO: zap into LP position
    //TODO: use bitmaps to naiively search for the tick closest to the new TWAP
    //TODO: assume everything will get filled for now
    //TODO: remove old latest tick if necessary
    //TODO: after accumulation, all liquidity below old latest tick is removed
    //TODO: don't update latestTick until TWAP has moved +/- tickSpacing
    //TODO: latestTick needs to be a multiple of tickSpacing
    

    //TODO: factor in swapFee
    //TODO: consider partial fills and how that impacts claims
    //TODO: consider current price...we might have to skip claims/burns from current tick
    function _updatePosition(
        address owner,
        int24 lower,
        int24 upper,
        int24 claim,
        bool zeroForOne,
        int128 amount
    ) internal {
        mapping (int24 => Tick) storage ticks = zeroForOne ? ticks0 : ticks1;
        UpdatePositionCache memory cache = UpdatePositionCache({
            position: zeroForOne ? positions0[owner][lower][upper] : positions1[owner][lower][upper],
            feeGrowthGlobalIn: zeroForOne ? pool0.feeGrowthGlobalIn : pool1.feeGrowthGlobalIn,
            priceLower: TickMath.getSqrtRatioAtTick(lower),
            priceUpper: TickMath.getSqrtRatioAtTick(upper),
            claimPrice: TickMath.getSqrtRatioAtTick(claim),
            removeLower: true,
            removeUpper: true,
            upperRemove: 0,
            lowerRemove: 0,
            amountInDelta: 0,
            amountOutDelta: 0
        });
console.log('claiming from lower:');
console.log(cache.position.liquidity);
        // validate removal amount is less than position liquidity
        if (amount < 0 && uint128(-amount) > cache.position.liquidity) revert NotEnoughPositionLiquidity();
        else if (amount < 0) cache.position.liquidity -= uint128(-amount);

        if (cache.position.claimPriceLast == 0) {
            cache.position.feeGrowthGlobalIn = cache.feeGrowthGlobalIn;
            cache.position.claimPriceLast = zeroForOne ? uint160(cache.priceUpper) : uint160(cache.priceLower);
        }
        if (cache.position.claimPriceLast > cache.claimPrice) revert InvalidClaimTick();
        // handle claims
        //TODO: figure out how to calculate current auction and withdraw liquidity from that
        //TODO: cannot skip claim process
        if(claim != (zeroForOne ? upper : lower) && ticks[claim].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) {
            // skip claim if lower == claim
            if(claim != (zeroForOne ? upper : lower)){
                // verify user passed highest tick with growth
                if (claim != (zeroForOne ? lower : upper)){

                    //TODO: if latestTick was just updated we can skip
                    //TODO: get dx from latestTick to current price for pool1
                    //TODO: get dy from currentPrice to claim tick for pool1
                    //TODO: do opposite for pool0
                    //TODO: add this to transferred amount if removing liquidity
                    {
                        // next tick should not have any fee growth
                        int24 claimNextTick = zeroForOne ? tickNodes[claim].previousTick : tickNodes[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) revert WrongTickClaimedAt();
                    }
                    Ticks.remove(
                        zeroForOne ? ticks0 : ticks1,
                        tickNodes,
                        zeroForOne ? lower : claim,
                        zeroForOne ? claim : upper,
                        uint128(-amount),
                        zeroForOne,
                        true,
                        true
                    );

                    //TODO: does uint -> int check for overflow?
                    cache.amountInDelta  = ticks[claim].amountInDelta;
                    cache.amountOutDelta = ticks[claim].amountOutDelta;
                    //TODO: move into Ticks lib ~ this code is 1.125 kb
                    // handle partial fill between lastestTick and current pool price
                    if (zeroForOne ? 
                            (latestTick < claim && latestTick >= lower) //TODO: not sure if second condition is possible
                          : (latestTick > claim && latestTick <= upper) 
                       ) {
                        uint160 latestTickPrice = TickMath.getSqrtRatioAtTick(latestTick);
                        //TODO: stop accumulating the tick before latestTick when moving TWAP
                        cache.amountInDelta += int128(int256(zeroForOne ? 
                                DyDxMath.getDy(
                                    1, // multiplied by liquidity later
                                    latestTickPrice,
                                    pool0.price,
                                    false
                                )
                                : DyDxMath.getDx(
                                    1, 
                                    pool1.price,
                                    latestTickPrice, 
                                    false
                                )
                        ));
                        //TODO: implement stopPrice for pool0/1
                        cache.amountOutDelta += int128(int256(zeroForOne ? 
                            DyDxMath.getDx(
                                1, // multiplied by liquidity later
                                pool0.price,
                                cache.claimPrice,
                                false
                            )
                            : DyDxMath.getDy(
                                1, 
                                cache.claimPrice,
                                pool1.price, 
                                false
                            )
                        ));
                        //TODO: do we need to handle minus deltas correctly depending on direction
                        // modify current liquidity
                        if (amount < 0) {
                            zeroForOne ? pool0.liquidity -= uint128(-amount) 
                                       : pool1.liquidity -= uint128(-amount);
                        }
                    }
                } else {
                            console.log('claiming from lower:');
                    {
                        // next tick having fee growth means liquidity was cleared
                        int24 claimNextTick = zeroForOne ? tickNodes[claim].previousTick : tickNodes[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) zeroForOne ? cache.removeLower = false 
                                                                                                                  : cache.removeUpper = false;
                    }
                    /// @dev - no liquidity removed from last tick
                    //ignore carryover for last tick of position
                    cache.amountInDelta  = ticks[claim].amountInDelta - int64(ticks[claim].amountInDeltaCarryPercent) 
                                                                            * ticks[claim].amountInDelta / 1e18;
                    cache.amountOutDelta = ticks[claim].amountOutDelta - int64(ticks[claim].amountOutDeltaCarryPercent)
                                                                            * ticks[claim].amountInDelta / 1e18;
                }
                cache.position.claimPriceLast = cache.claimPrice;
                {
                    // calculate what is claimable
                    //TODO: should this be inside Ticks library?
                    uint256 amountInClaimable  = zeroForOne ? 
                                                    DyDxMath.getDy(
                                                        cache.position.liquidity,
                                                        cache.claimPrice,
                                                        cache.position.claimPriceLast,
                                                        false
                                                    )
                                                  : DyDxMath.getDx(
                                                        cache.position.liquidity, 
                                                        cache.position.claimPriceLast,
                                                        cache.claimPrice, 
                                                        false
                                                    );
                    if (cache.amountInDelta > 0) {
                        amountInClaimable += FullPrecisionMath.mulDiv(
                                                                        uint128(cache.amountInDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    } else if (cache.amountInDelta < 0) {
                        //TODO: handle underflow here
                        amountInClaimable -= FullPrecisionMath.mulDiv(
                                                                        uint128(-cache.amountInDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    }
                    //TODO: add to position
                    if (amountInClaimable > 0) {
                        amountInClaimable *= (1e6 + swapFee) / 1e6; // factor in swap fees
                        _transferOut(owner, zeroForOne ? token1 : token0, amountInClaimable);
                    }
                }
                {
                    if (cache.amountOutDelta > 0) {
                        uint256 amountOutClaimable = FullPrecisionMath.mulDiv(
                                                                        uint128(cache.amountOutDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                        //TODO: ADD TO POSITION INSTEAD
                        _transferOut(owner, zeroForOne ? token0 : token1, amountOutClaimable);
                    }
                    //TODO: add to position
                }
            }
        // user can claim with no updates from lower
        } else if ((zeroForOne ? claim == upper : claim == lower) && amount < 0) {
            console.log('zero previous tick6:');
            //TODO: if claim is start of position, ignore deltas
            {
                // next tick should not have any fee growth
                //TODO: this should be impossible if lower fee growth is equal to position
                int24 claimNextTick = zeroForOne ? tickNodes[claim].previousTick : tickNodes[claim].nextTick;
                if (ticks[claimNextTick].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) revert WrongTickClaimedAt();
            }
            if (amount < 0){
                console.log('fee growth check:');
                //only if feeGrowth has not increased
                console.logInt(ticks1[upper].liquidityDelta);
                console.log(cache.position.feeGrowthGlobalIn);
                cache.removeLower = zeroForOne ? 
                                          ticks0[tickNodes[lower].previousTick].feeGrowthGlobalIn <= cache.position.feeGrowthGlobalIn
                                        : ticks1[tickNodes[claim].nextTick].feeGrowthGlobalIn <= cache.position.feeGrowthGlobalIn;
                cache.removeUpper = zeroForOne ? 
                                          ticks0[tickNodes[claim].previousTick].feeGrowthGlobalIn <= cache.position.feeGrowthGlobalIn
                                        : ticks1[tickNodes[upper].nextTick].feeGrowthGlobalIn <= cache.position.feeGrowthGlobalIn;
                console.log(cache.removeLower);
                Ticks.remove(
                    zeroForOne ? ticks0 : ticks1,
                    tickNodes,
                    lower,
                    upper,
                    uint128(-amount),
                    zeroForOne,
                    cache.removeLower,
                    cache.removeUpper
                );
                console.log('zero previous tick6:');
                uint256 amountOutRemoved = zeroForOne ? 
                                    DyDxMath.getDx(
                                        uint128(-amount),
                                        cache.priceLower,
                                        cache.claimPrice,
                                        false
                                    )
                                  : DyDxMath.getDy(
                                        uint128(-amount),
                                        cache.claimPrice,
                                        cache.priceUpper,
                                        false
                                    );
                _transferOut(owner, zeroForOne ? token0 : token1, amountOutRemoved);
            }
        } else if (zeroForOne ? claim != upper : claim != lower) {
            //user needs to withdraw liquidity from highest tick possible
            revert WrongTickClaimedAt();
        } 

        console.log('zero previous tick2:');

        if (amount > 0) {
            // handle double minting of position
            if(cache.position.liquidity > 0) {
                zeroForOne ? 
                delete positions0[owner][lower][upper]
              : delete positions1[owner][lower][upper];
            }
            cache.position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (cache.position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }

        zeroForOne ? positions0[owner][lower][claim] = cache.position 
                   : positions1[owner][claim][upper] = cache.position;
    }
}
