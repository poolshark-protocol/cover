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

    constructor(bytes memory _poolParams) {
        (
            address _factory,
            address _inputPool,
            address _libraries,
            uint24  _swapFee, 
            int24  _tickSpacing
        ) = abi.decode(
            _poolParams,
            (
                address, 
                address,
                address,
                uint24,
                int24
            )
        );

        // check for invalid params
        if (_swapFee > MAX_FEE) revert InvalidSwapFee();

        // set state variables from params
        factory     = _factory;
        inputPool   = IConcentratedPool(_inputPool);
        utils       = IPoolsharkUtils(_libraries);
        token0      = IConcentratedPool(inputPool).token0();
        token1      = IConcentratedPool(inputPool).token1();
        swapFee     = _swapFee;
        //TODO: should be 1% for .1% spacing on inputPool
        tickSpacing = _tickSpacing;

        // extrapolate other state variables
        feeTo = IPoolsharkHedgePoolFactory(_factory).owner();
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

    function mint(
        int24 lowerOld,
        int24 lower,
        int24 upperOld,
        int24 upper,
        uint128 amountDesired,
        bool zeroForOne,
        bool native
    ) external lock {
        _mint(
            MintParams(
                lowerOld,
                lower,
                upperOld,
                upper,
                amountDesired,
                zeroForOne,
                native
            )
        );
    }

    /// @dev Mints LP tokens - should be called via the CL pool manager contract.
    function _mint(MintParams memory mintParams) internal returns (uint256 liquidityMinted) {
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
        //TODO: handle upperOld and lowerOld being invalid
        uint256 priceLower = uint256(TickMath.getSqrtRatioAtTick(mintParams.lower));
        uint256 priceUpper = uint256(TickMath.getSqrtRatioAtTick(mintParams.upper));
        //TODO: maybe move to other function
        // handle partial mints
        if (mintParams.zeroForOne && mintParams.upper >= latestTick) {
            mintParams.upper = latestTick - int24(tickSpacing);
            mintParams.upperOld = latestTick;
            uint256 priceNewUpper = TickMath.getSqrtRatioAtTick(mintParams.upper);
            mintParams.amountDesired -= uint128(DyDxMath.getDx(liquidityMinted, priceNewUpper, priceUpper, false));
            priceUpper = priceNewUpper;
        }
        if (!mintParams.zeroForOne && mintParams.lower <= latestTick) {
            mintParams.lower = latestTick + int24(tickSpacing);
            mintParams.lowerOld = latestTick;
            uint256 priceNewLower = TickMath.getSqrtRatioAtTick(mintParams.lower);
            mintParams.amountDesired -= uint128(DyDxMath.getDy(liquidityMinted, priceLower, priceNewLower, false));
            priceLower = priceNewLower;
        }

        _validatePosition(mintParams);

        liquidityMinted = DyDxMath.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            mintParams.zeroForOne ? priceLower : priceUpper,
            mintParams.zeroForOne ? 0 : uint256(mintParams.amountDesired),
            mintParams.zeroForOne ? uint256(mintParams.amountDesired) : 0
        );

        // Ensure no overflow happens when we cast from uint256 to int128.
        if (liquidityMinted > uint128(type(int128).max)) revert LiquidityOverflow();

        if(mintParams.zeroForOne){
            _transferIn(token0, mintParams.amountDesired);
        } else {
            _transferIn(token1, mintParams.amountDesired);
        }

        unchecked {
            _updatePosition(
                msg.sender,
                mintParams.lower,
                mintParams.upper,
                mintParams.zeroForOne ? mintParams.upper : mintParams.lower,
                mintParams.zeroForOne,
                int128(uint128(liquidityMinted))
            );
            /// @dev - pool current liquidity should never be increased on mint
        }

        Ticks.insert(
            mintParams.zeroForOne ? ticks0 : ticks1,
            tickNodes,
            latestTick,
            mintParams.zeroForOne ? pool0.feeGrowthGlobalIn : pool1.feeGrowthGlobalIn,
            mintParams.lowerOld,
            mintParams.lower,
            mintParams.upperOld,
            mintParams.upper,
            uint128(liquidityMinted),
            mintParams.zeroForOne
        );

        (uint128 amountInActual, uint128 amountOutActual) = DyDxMath.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            mintParams.zeroForOne ? priceLower : priceUpper,
            liquidityMinted,
            true
        );

        emit Mint(msg.sender, amountInActual, amountOutActual);
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
        // console.log('zero previous tick:');
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

        uint256 amountIn;
        uint256 amountOut;

        //TODO: get token amounts from _updatePosition return values
        emit Burn(msg.sender, amountIn, amountOut);
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

    function _validatePosition(MintParams memory mintParams) internal view {
        if (mintParams.lower % int24(tickSpacing) != 0) revert InvalidTick();
        if (mintParams.upper % int24(tickSpacing) != 0) revert InvalidTick();
        if (mintParams.amountDesired == 0) revert InvalidPosition();
        if (mintParams.lower >= mintParams.upper) revert InvalidPosition();
        if (mintParams.zeroForOne) {
            if (mintParams.lower >= latestTick) revert InvalidPosition();
        } else {
            // console.log('upper param');
            // console.logInt(mintParams.upper);
            // console.logInt(latestTick);
            if (mintParams.upper <= latestTick) revert InvalidPosition();
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
            lowerRemove: 0
        });

        // validate removal amount is less than position liquidity
        if (amount < 0 && uint128(-amount) > cache.position.liquidity) revert NotEnoughPositionLiquidity();

        if (cache.position.claimPriceLast == 0) {
            cache.position.feeGrowthGlobalIn = cache.feeGrowthGlobalIn;
            cache.position.claimPriceLast = zeroForOne ? uint160(cache.priceUpper) : uint160(cache.priceLower);
        }
        if (cache.position.claimPriceLast > cache.claimPrice) revert InvalidClaimTick();

        // handle claims
        if(ticks[claim].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) {
            // skip claim if lower == claim
            if(claim != (zeroForOne ? upper : lower)){
                // verify user passed highest tick with growth
                if (claim != (zeroForOne ? lower : upper)){
                    //TODO: factor in deltas including carryover
                    //TODO: remove liquidity from claim tick
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
                } else {
                    //TODO: factor in deltas excluding carryover
                    //remove liquidity from last tick only
                    {
                        // next tick having fee growth means liquidity was cleared
                        int24 claimNextTick = zeroForOne ? tickNodes[claim].previousTick : tickNodes[claim].nextTick;
                        if (ticks[claimNextTick].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) zeroForOne ? cache.removeLower = false 
                                                                                                                  : cache.removeUpper = false;
                    }
                    Ticks.remove(
                        zeroForOne ? ticks0 : ticks1,
                        tickNodes,
                        zeroForOne ? lower : claim,
                        zeroForOne ? claim : upper,
                        uint128(-amount),
                        zeroForOne,
                        zeroForOne ? cache.removeLower : false,
                        zeroForOne ? false : cache.removeUpper
                    );
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
                                                    ); // * (1e6 + swapFee) / 1e6; //factors in fees 
                    int128 amountInDelta = ticks[claim].amountInDelta;
                    if (amountInDelta > 0) {
                        amountInClaimable += FullPrecisionMath.mulDiv(
                                                                        uint128(amountInDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    } else if (amountInDelta < 0) {
                        //TODO: handle underflow here
                        amountInClaimable -= FullPrecisionMath.mulDiv(
                                                                        uint128(-amountInDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                    }
                    //TODO: add to position
                    if (amountInClaimable > 0) {
                        _transferOut(owner, zeroForOne ? token1 : token0, amountInClaimable);
                    }
                }
                {
                    int128 amountOutDelta = ticks[claim].amountOutDelta;
                    uint256 amountOutClaimable;
                    if (amountOutDelta > 0) {
                        amountOutClaimable = FullPrecisionMath.mulDiv(
                                                                        uint128(amountOutDelta),
                                                                        cache.position.liquidity, 
                                                                        Ticks.Q128
                                                                    );
                        //TODO: change to one transfer
                        _transferOut(owner, zeroForOne ? token0 : token1, amountOutClaimable);
                    }
                    //TODO: add to position
                }
            }
        // user can claim with no updates from lower
        } else if ((zeroForOne ? claim == upper : claim == lower) && amount < 0) {
            //TODO: if claim is start of position, ignore deltas
            {
                // next tick should not have any fee growth
                //TODO: this should be impossible if lower fee growth is equal to position
                int24 claimNextTick = zeroForOne ? tickNodes[claim].previousTick : tickNodes[claim].nextTick;
                if (ticks[claimNextTick].feeGrowthGlobalIn > cache.position.feeGrowthGlobalIn) revert WrongTickClaimedAt();
            }
            if (amount < 0){
                Ticks.remove(
                    zeroForOne ? ticks0 : ticks1,
                    tickNodes,
                    lower,
                    upper,
                    uint128(-amount),
                    zeroForOne,
                    true,
                    true
                );
            }
        } else if (zeroForOne ? claim != upper : claim != lower) {
            //user needs to withdraw liquidity from highest tick possible
            revert WrongTickClaimedAt();
        } 
        //TODO: should we revert otherwise? 

        // liquidity updated in burn() function
        if (amount < 0) {
            // calculate amount to transfer out
            // TODO: ensure no liquidity above has been touched

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

            // console.log('amount out removed:', amountOutRemoved);
            // will underflow if too much liquidity withdrawn
            uint128 liquidityAmount = uint128(-amount);
            cache.position.liquidity -= liquidityAmount;
            _transferOut(owner, zeroForOne ? token0 : token1, amountOutRemoved);
        }

        if (amount > 0) {
            //TODO: i'm not sure how to handle double mints just yet
            // one solution is to take all their current liquidity
            // and then respread it over whatever range they select
            // if they haven't claimed at all it's fine
            // second solution is to recalculate claimPriceLast
            // easiest option is to just reset the position
            // and store the leftover amounts in the position
            // or transfer the leftover balance to the owner
            //TODO: handle double minting of position
            if(cache.position.liquidity > 0) revert NotImplementedYet();
            cache.position.liquidity += uint128(amount);
            // Prevents a global liquidity overflow in even if all ticks are initialised.
            if (cache.position.liquidity > MAX_TICK_LIQUIDITY) revert LiquidityOverflow();
        }

        zeroForOne ? positions0[owner][lower][upper] = cache.position 
                   : positions1[owner][lower][upper] = cache.position;
    }
}
