// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import './CoverPoolFactory.sol';
import './utils/CoverPoolManager.sol';
import './test/Token20.sol';
import './utils/PositionERC1155.sol';
import './interfaces/structs/CoverPoolStructs.sol';
import './libraries/math/ConstantProduct.sol';
import './libraries/pool/MintCall.sol';
import './libraries/pool/BurnCall.sol';
import './test/UniswapV3FactoryMock.sol';
import './libraries/sources/UniswapV3Source.sol';

//TODO: make sure no assertions fail
//TODO: add the ability to change the TWAP randomly

// Fuzz CoverPool functionality
contract CoverEchidnaPool {

    event PassedMint();
    event PassedBurn();
    event Prices(uint160 price0, uint160 price1);
    event LiquidityGlobal(uint128 liqBefore, uint128 liqAfter);
    event Liquidity(uint128 liq0Before, uint128 liq1Before, uint128 liq0After, uint128 liq1After);
    event PositionTicks(int24 lower, int24 upper);
    event BurnTicks(int24 lower, int24 upper, bool positionExists);
    event LiquidityMinted(uint256 amount, uint256 tokenAmount, bool zeroForOne);
    event PositionCreated(bool isCreated);
    event AmountInDeltaMaxMinus(uint128 beforeDelta, uint128 afterDelta);
    event AmountOutDeltaMaxMinus(uint128 beforeDelta, uint128 afterDelta);
    event LiquidityDeltaAndDeltaMaxMinus(int128 delta, uint128 abs);
    event Deployed(address contractAddress);

    int16 private constant tickSpread = 20;
    int16 private constant MAX_TICK_JUMP = 200; // i.e. 10 * tickSpread
    int24 private constant MAX_TICK = 887260;
    int24 private constant MIN_TICK = -MAX_TICK;
    address private immutable poolImpl;
    address private immutable tokenImpl;
    address private immutable poolMock;
    address private immutable poolFactoryMock;
    address private immutable twapSource;
    CoverPoolFactory private immutable factory;
    CoverPoolManager private immutable manager;
    CoverPool private immutable pool;
    PositionERC1155 private immutable token;
    Token20 private immutable token0;
    Token20 private immutable token1;
    Token20 private immutable tokenIn;
    Token20 private immutable tokenOut;
    Position[] private positions;

    struct LiquidityDeltaValues {
        int128 liquidityDeltaLowerBefore;
        int128 liquidityDeltaUpperBefore;
        int128 liquidityDeltaLowerAfter;
        int128 liquidityDeltaUpperAfter;
    }

    struct PoolValues {
        uint160 price0Before;
        uint128 liquidity0Before;
        uint160 price1Before;
        uint128 liquidity1Before;
        uint160 price0After;
        uint128 liquidity0After;
        uint160 price1After;
        uint128 liquidity1After;

        uint128 liquidityGlobalBefore;
        uint128 liquidityGlobalAfter;

        int24 latestTickBefore;
        int24 latestTickAfter;

        // CoverPoolStructs.PoolState pool0Before;
        // CoverPoolStructs.PoolState pool1Before;
        // CoverPoolStructs.GlobalState stateBefore;
        // CoverPoolStructs.GlobalState stateAfter;

        // CoverPoolStructs.Tick tickLowerBefore;
        // CoverPoolStructs.Tick tickUpperBefore;
        // CoverPoolStructs.Tick tickLowerAfter;
        // CoverPoolStructs.Tick tickUpperAfter;

        uint128 amountInDeltaMaxMinusUpperBefore;
        uint128 amountInDeltaMaxMinusLowerBefore;
        uint128 amountInDeltaMaxMinusUpperAfter;
        uint128 amountInDeltaMaxMinusLowerAfter;

        uint128 amountOutDeltaMaxMinusUpperBefore;
        uint128 amountOutDeltaMaxMinusLowerBefore;
        uint128 amountOutDeltaMaxMinusUpperAfter;
        uint128 amountOutDeltaMaxMinusLowerAfter;

        uint160 price0;
        uint160 price1;

        uint32 positionIdNextBefore;
        uint32 positionIdNextAfter;
    }

    struct SwapCallbackData {
        address sender;
    }

    struct Position {
        address owner;
        uint32 positionId;
        int24 lower;
        int24 upper;
        bool zeroForOne;
    }

    struct PoolStructs {
        CoverPoolStructs.Tick lower;
        CoverPoolStructs.Tick upper;
        CoverPoolStructs.PoolState pool0;
        CoverPoolStructs.PoolState pool1;
        CoverPoolStructs.GlobalState state;
        PoolsharkStructs.CoverImmutables constants;
    }

    modifier tickPreconditions(int24 lower, int24 upper) {
        require(lower < upper);
        require(upper <= MAX_TICK);
        require(lower >= MIN_TICK);
        require(lower % tickSpread == 0);
        require(upper % tickSpread == 0);
        _;
    }

    constructor() {
        manager = new CoverPoolManager();
        factory = new CoverPoolFactory(address(manager));
        poolImpl = address(new CoverPool(address(factory)));
        tokenImpl = address(new PositionERC1155(address(factory)));
        tokenIn = new Token20("IN", "IN", 18);
        tokenOut = new Token20("OUT", "OUT", 18);
        (token0, token1) = address(tokenIn) < address(tokenOut) ? (tokenIn, tokenOut) 
                                                                : (tokenOut, tokenIn);

        // mock sources
        poolFactoryMock = address(new UniswapV3FactoryMock(address(tokenIn), address(tokenOut)));
        twapSource = address(new UniswapV3Source(poolFactoryMock));

        poolMock = UniswapV3FactoryMock(poolFactoryMock).getPool(address(token0), address(token1), 500);
        emit Deployed(UniswapV3FactoryMock(poolFactoryMock).getPool(address(token0), address(token1), 500));
        UniswapV3PoolMock(poolMock).setObservationCardinality(5, 5);

        CoverPoolStructs.VolatilityTier memory volTier = CoverPoolStructs.VolatilityTier({
            minAmountPerAuction: 0,
            auctionLength: 5,
            blockTime: 1000,
            syncFee: 0,
            fillFee: 0,
            minPositionWidth: 1,
            minAmountLowerPriced: true
        });
        
        // add pool type
        manager.enablePoolType(bytes32(uint256(0x1)), poolImpl, tokenImpl, twapSource);
        manager.enableVolatilityTier(bytes32(uint256(0x1)), 500, 20, 5, volTier);
        ICoverPoolFactory.CoverPoolParams memory params;
        params.poolType = bytes32(uint256(0x1));
        params.tokenIn = address(tokenIn);
        params.tokenOut = address(tokenOut);
        params.feeTier = 500;
        params.tickSpread = 20;
        params.twapLength = 5;

        // launch pool
        address poolAddr; address poolToken;
        (poolAddr, poolToken) = factory.createCoverPool(params);
        pool = CoverPool(poolAddr);
        token = PositionERC1155(poolToken);
    }

    function mint(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        mintAndApprove();
        amount = amount + 1;
        
        // Ensure the newly created position is using different ticks
        for(uint i = 0; i < positions.length;) {
            if(positions[i].owner == msg.sender && positions[i].lower == lower && positions[i].upper == upper && positions[i].zeroForOne == zeroForOne) {
                revert("Position already exists");
            }
            unchecked {
                ++i;
            }
        }

        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;
        
        // storage structs
        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        // pool price and liquidity
        poolValues.price0Before = poolStructs.pool0.price;
        poolValues.liquidity0Before = poolStructs.pool0.liquidity;
        poolValues.price1Before = poolStructs.pool1.price;
        poolValues.liquidity1Before = poolStructs.pool1.liquidity;
        poolValues.liquidityGlobalBefore = poolStructs.state.liquidityGlobal;

        // tick values
        values.liquidityDeltaLowerBefore = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperBefore = poolStructs.upper.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerBefore = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = poolStructs.upper.amountInDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        ICoverPool.MintParams memory params;
        params.to = msg.sender;
        params.amount = amount;
        params.positionId = 0;
        params.lower = lower;
        params.upper = upper;
        params.zeroForOne = zeroForOne;

        // Get the ticks the position will be minted with rather than what was passed directly by fuzzer
        // This is so the we can properly compare before and after mint states of particular ticks.
        bool posCreated;
        (lower, upper, posCreated) = pool.getResizedTicksForMint(params);
        //TODO: amount can change as well here so we should change this functionality or account for the change
        emit PositionTicks(lower, upper);
        emit PositionCreated(posCreated);

        // ACTION 
        pool.mint(params);
        if (posCreated) positions.push(Position(msg.sender, poolValues.positionIdNextBefore, lower, upper, zeroForOne));

        // storage structs
        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        // pool price and liquidity
        poolValues.price0After = poolStructs.pool0.price;
        poolValues.liquidity0After = poolStructs.pool0.liquidity;
        poolValues.price1After = poolStructs.pool1.price;
        poolValues.liquidity1After = poolStructs.pool1.liquidity;
        poolValues.liquidityGlobalAfter = poolStructs.state.liquidityGlobal;

        // lower tick
        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerAfter = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;

        // upper tick
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountInDeltaMaxMinusUpperAfter = poolStructs.upper.amountInDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;
        
        // POST CONDITIONS

        // Ensure prices have not crossed
        emit Prices(poolValues.price0After, poolValues.price1After);
        assert(poolValues.price0After <= poolValues.price1After);
        
        // Ensure that amountOutDeltaMaxMinus is incremented when not undercutting
        if (posCreated) {
            emit PositionTicks(lower, upper);
            // Ensure positions ticks arent crossed
            assert(lower < upper);
            // Ensure minted ticks on proper tick spacing
            assert((lower % tickSpread == 0) && (upper % tickSpread == 0));

            // check delta maxes
            if(zeroForOne){
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusLowerBefore, poolValues.amountInDeltaMaxMinusLowerAfter);
                assert(poolValues.amountInDeltaMaxMinusLowerAfter > poolValues.amountInDeltaMaxMinusLowerBefore);
                emit AmountOutDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusLowerBefore, poolValues.amountOutDeltaMaxMinusLowerAfter);
                assert(poolValues.amountOutDeltaMaxMinusLowerAfter > poolValues.amountOutDeltaMaxMinusLowerBefore);
            } else {
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusUpperBefore, poolValues.amountInDeltaMaxMinusUpperAfter);
                assert(poolValues.amountInDeltaMaxMinusUpperAfter > poolValues.amountInDeltaMaxMinusUpperBefore);
                emit AmountOutDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusUpperBefore, poolValues.amountOutDeltaMaxMinusUpperAfter);
                assert(poolValues.amountOutDeltaMaxMinusUpperAfter > poolValues.amountOutDeltaMaxMinusUpperBefore);
            }
            emit LiquidityGlobal(poolValues.liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
            //emit Liquidity(poolValues.liquidity0Before, poolValues.liquidity1Before, poolValues.liquidity0After, poolValues.liquidity1After);
            // Ensure liquidityGlobal is incremented after mint
            assert(poolValues.liquidityGlobalAfter > poolValues.liquidityGlobalBefore);
        }
        // Ensure pool liquidity is non-zero after mint with no undercuts
        // if (zeroForOne) {
        //     if (poolValues.price0After < poolValues.price0Before) assert(poolValues.liquidity0After > 0);
        // }
        // else {
        //     if (poolValues.price1After > poolValues.price1Before) assert(poolValues.liquidity1After > 0);
        // }
    }

    function mintVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        // check if it's going to sync beforehand
        mintAndApprove();
        amount = amount + 1;
        // Ensure the newly created position is using different ticks
        for(uint i = 0; i < positions.length;) {
            if(positions[i].owner == msg.sender && positions[i].lower == lower && positions[i].upper == upper && positions[i].zeroForOne == zeroForOne) {
                revert("Position already exists");
            }
            unchecked {
                ++i;
            }
        }

        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;

        // storage structs
        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        // pool price and liquidity
        poolValues.price0Before = poolStructs.pool0.price;
        poolValues.liquidity0Before = poolStructs.pool0.liquidity;
        poolValues.price1Before = poolStructs.pool1.price;
        poolValues.liquidity1Before = poolStructs.pool1.liquidity;
        poolValues.liquidityGlobalBefore = poolStructs.state.liquidityGlobal;

        // tick values
        values.liquidityDeltaLowerBefore = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperBefore = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        ICoverPool.MintParams memory params;
        params.to = msg.sender;
        params.amount = amount;
        params.lower = lower;
        params.upper = upper;
        params.zeroForOne = zeroForOne;

        // Get the ticks the position will be minted with rather than what was passed directly by fuzzer
        // This is so the we can properly compare before and after mint states of particular ticks.
        bool posCreated;
        (lower, upper, posCreated) = pool.getResizedTicksForMint(params);
        emit PositionTicks(lower, upper);
        emit PositionCreated(posCreated);

        // ACTION 
        pool.mint(params);
        if (posCreated) positions.push(Position(msg.sender, poolValues.positionIdNextBefore, lower, upper, zeroForOne));

        // pool price and liquidity
        poolValues.price0After = poolStructs.pool0.price;
        poolValues.liquidity0After = poolStructs.pool0.liquidity;
        poolValues.price1After = poolStructs.pool1.price;
        poolValues.liquidity1After = poolStructs.pool1.liquidity;
        poolValues.liquidityGlobalAfter = poolStructs.state.liquidityGlobal;

        // tick values
        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;

        // POST CONDITIONS

        // Ensure prices have not crossed
        emit Prices(poolValues.price0After, poolValues.price1After);
        assert(poolValues.price0After <= poolValues.price1After);

        // Ensure liquidityDelta is always less or equal to amountOutDeltaMaxMinus
        if(zeroForOne){
            emit AmountInDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusLowerBefore, poolValues.amountOutDeltaMaxMinusLowerAfter);
            assert(poolValues.amountOutDeltaMaxMinusLowerAfter >= poolValues.amountOutDeltaMaxMinusLowerBefore);
            emit AmountOutDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusLowerBefore, poolValues.amountOutDeltaMaxMinusLowerAfter);
            assert(poolValues.amountOutDeltaMaxMinusLowerAfter >= poolValues.amountOutDeltaMaxMinusLowerBefore);
        } else {
            emit AmountInDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusUpperBefore, poolValues.amountOutDeltaMaxMinusUpperAfter);
            assert(poolValues.amountOutDeltaMaxMinusUpperAfter >= poolValues.amountOutDeltaMaxMinusUpperBefore);
            emit AmountOutDeltaMaxMinus(poolValues.amountOutDeltaMaxMinusUpperBefore, poolValues.amountOutDeltaMaxMinusUpperAfter);
            assert(poolValues.amountOutDeltaMaxMinusUpperAfter >= poolValues.amountOutDeltaMaxMinusUpperBefore);
        }

        if (posCreated) {
            emit PositionTicks(lower, upper);
            // Ensure positions ticks arent crossed
            assert(lower < upper);
            // Ensure minted ticks on proper tick spacing
            assert((lower % tickSpread == 0) && (upper % tickSpread == 0));
        }
        
        emit LiquidityGlobal(poolValues.liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        emit Liquidity(poolValues.liquidity0Before, poolValues.liquidity1Before, poolValues.liquidity0After, poolValues.liquidity1After);
        
        // Ensure liquidityGlobal is incremented after mint
        assert(poolValues.liquidityGlobalAfter >= poolValues.liquidityGlobalBefore);

        // Ensure pool liquidity is non-zero after mint with no undercuts
        // if (zeroForOne) {
        //     if (poolValues.price0After < poolValues.price0Before) assert(poolValues.liquidity0After > 0);
        // }
        // else {
        //     if (poolValues.price1After > poolValues.price1Before) assert(poolValues.liquidity1After > 0);
        // }
    }

    function swap(uint160 priceLimit, uint128 amount, bool zeroForOne) public {
        // PRE CONDITIONS
        mintAndApprove();

        CoverPoolStructs.SwapParams memory params;
        params.to = msg.sender;
        params.priceLimit = priceLimit;
        params.amount = amount;
        params.exactIn = true; // TODO: exactIn always true for now
        params.zeroForOne = zeroForOne;
        params.callbackData = abi.encodePacked(address(this));
        
        // ACTION
        pool.swap(params);

        // POST CONDITIONS
        CoverPoolStructs.PoolState memory pool0 = getPoolState(true);
        CoverPoolStructs.PoolState memory pool1 = getPoolState(false);
        uint160 price0 = pool0.price;
        uint160 price1 = pool1.price;
        
        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 <= price1);
    }

    function syncTick(int24 newLatestTick, bool autoSync) public  {
        PoolStructs memory poolStructs;
        poolStructs.state = getGlobalState();
        poolStructs.constants = pool.immutables();

        // gate tick jump
        if (newLatestTick < poolStructs.state.latestTick - MAX_TICK_JUMP)
            newLatestTick = poolStructs.state.latestTick - MAX_TICK_JUMP;
        else if (newLatestTick > poolStructs.state.latestTick + MAX_TICK_JUMP)
            newLatestTick = poolStructs.state.latestTick + MAX_TICK_JUMP;

        UniswapV3PoolMock(poolMock).setTickCumulatives(
            newLatestTick * 10,
            newLatestTick * 8,
            newLatestTick * 7,
            newLatestTick * 5
        );

        if (autoSync) {
            // quote of 0 should start at new tick
            //TODO: find new latest tick based on auction depth
            CoverPoolStructs.SwapParams memory params;
            params.to = msg.sender;
            params.priceLimit = 0;
            params.amount = 0;
            params.exactIn = true;
            params.zeroForOne = true;
            params.callbackData = abi.encodePacked(address(this));
        
            // ACTION
            pool.swap(params);

            // POST CONDITIONS
            //TODO: find new latest tick based on auction depth
            //new latestTick should match
            //if there was liquidity delta on that tick it should be unlocked
            //amountInDelta should be zeroed out if tick moved
            poolStructs.pool0 = getPoolState(true);
            poolStructs.pool1 = getPoolState(false);
            poolStructs.state = getGlobalState();
            emit Prices(poolStructs.pool0.price, poolStructs.pool1.price);
            assert(poolStructs.pool0.price <= poolStructs.pool1.price);
        }
    }

    function burn(int24 claimAt, uint256 positionIndex, uint128 burnPercent) public {
        // PRE CONDITIONS
        positionIndex = positionIndex % positions.length;
        Position memory pos = positions[positionIndex];
        require(claimAt >= pos.lower && claimAt <= pos.upper);
        require(claimAt % tickSpread == 0);
        PoolStructs memory poolStructs;
        PoolValues memory poolValues;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(pos.lower);
        poolStructs.upper = getTick(pos.upper);

        ICoverPool.BurnParams memory params;
        params.to = pos.owner;
        params.burnPercent = burnPercent == 1e38 ? burnPercent : _between(burnPercent, 1e36, 1e38); //1e38;
        params.positionId = pos.positionId;
        params.claim = claimAt;
        params.zeroForOne = pos.zeroForOne;

        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;
        poolValues.liquidityGlobalBefore = poolStructs.state.liquidityGlobal;
        
        emit PositionTicks(pos.lower, pos.upper);
        (int24 lower, int24 upper, bool positionExists) = pool.getResizedTicksForBurn(params);
        emit BurnTicks(lower, upper, positionExists);

        // ACTION
        pool.burn(params);
        if (!positionExists) {
            positions[positionIndex] = positions[positions.length - 1];
            delete positions[positions.length - 1];
        }
        else {
            // Update position data in array if not fully burned
            positions[positionIndex] = Position(pos.owner, pos.positionId, lower, upper, pos.zeroForOne);
            // Ensure positions ticks arent crossed
            assert(lower < upper);
            // Ensure minted ticks on proper tick spacing
            assert((lower % tickSpread == 0) && (upper % tickSpread == 0));
        }

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(pos.lower);
        poolStructs.upper = getTick(pos.upper);

        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;
        poolValues.liquidityGlobalAfter = poolStructs.state.liquidityGlobal;

        uint160 price0 = poolStructs.pool0.price;
        uint160 price1 = poolStructs.pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 <= price1);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(poolValues.liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert((poolValues.liquidityGlobalAfter <= poolValues.liquidityGlobalBefore));
    }

    function claim(int24 claimAt, uint256 positionIndex) public {
        // PRE CONDITIONS
        positionIndex = positionIndex % positions.length;
        Position memory pos = positions[positionIndex];
        claimAt = pos.lower + (claimAt % (pos.upper - pos.lower));
        require(claimAt % tickSpread == 0);

        // PoolValues memory poolValues;
        PoolStructs memory poolStructs;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(pos.lower);
        poolStructs.upper = getTick(pos.upper);

        ICoverPool.BurnParams memory params;
        params.to = pos.owner;
        params.burnPercent = 0;
        params.positionId = pos.positionId;
        params.claim = claimAt;
        params.zeroForOne = pos.zeroForOne;
        
        emit PositionTicks(pos.lower, pos.upper);
        (int24 lower, int24 upper, bool positionExists) = pool.getResizedTicksForBurn(params);
        emit BurnTicks(lower, upper, positionExists);

        // ACTION
        pool.burn(params);
        if (!positionExists) {
            positions[positionIndex] = positions[positions.length - 1];
            delete positions[positions.length - 1];
        }
        else {
            // Update position data in array if not fully burned
            positions[positionIndex] = Position(pos.owner, pos.positionId, lower, upper, pos.zeroForOne);
            // Ensure positions ticks arent crossed
            assert(lower < upper);
            // Ensure minted ticks on proper tick spacing
            assert((lower % tickSpread == 0) && (upper % tickSpread == 0));
        }

        // POST CONDITIONS
        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(pos.lower);
        poolStructs.upper = getTick(pos.upper);

        uint160 price0 = poolStructs.pool0.price;
        uint160 price1 = poolStructs.pool1.price;

        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 <= price1);
    }

    function mintThenBurnZeroLiquidityChangeVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        mintAndApprove();
        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        // ACTION 
        mintVariable(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        // POST CONDITIONS
        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;

        uint160 price0After = poolStructs.pool0.price;
        uint160 price1After = poolStructs.pool1.price;
        poolValues.liquidityGlobalAfter = poolStructs.state.liquidityGlobal;

        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After <= price1After);

        // Ensure liquidityGlobal is decremented after burn
        // emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        // assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenBurnZeroLiquidityChange(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        mintAndApprove();
        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        // ACTION 
        mint(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;

        uint160 price0After = poolStructs.pool0.price;
        uint160 price1After = poolStructs.pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After <= price1After);

        // Ensure liquidityGlobal is decremented after burn
        // emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        // assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenPartialBurnTwiceLiquidityChange(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint128 percent) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        percent = 1 + (percent % (1e38 - 1));
        mintAndApprove();
        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        // ACTION 
        mint(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, percent);
        emit PassedBurn();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;

        uint160 price0After = poolStructs.pool0.price;
        uint160 price1After = poolStructs.pool1.price;

        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After <= price1After);

        // Ensure liquidityGlobal is decremented after burn
        // emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        // assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenPartialBurnTwiceLiquidityChangeVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint128 percent) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        percent = 1 + (percent % (1e38 - 1));
        mintAndApprove();
        PoolValues memory poolValues;
        PoolStructs memory poolStructs;
        LiquidityDeltaValues memory values;

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        poolValues.amountOutDeltaMaxMinusLowerBefore = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperBefore = poolStructs.upper.amountOutDeltaMaxMinus;

        // ACTION 
        mintVariable(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, percent);
        emit PassedBurn();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        poolStructs.pool0 = getPoolState(true);
        poolStructs.pool1 = getPoolState(false);
        poolStructs.state = getGlobalState();
        poolStructs.lower = getTick(lower);
        poolStructs.upper = getTick(upper);

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;

        uint160 price0After = poolStructs.pool0.price;
        uint160 price1After = poolStructs.pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After <= price1After);

        // Ensure liquidityGlobal is decremented after burn
        // emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        // assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function coverPoolSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta < 0) {
            SafeTransfers.transferInto(address(token0), address(pool), uint256(-amount0Delta));
        } else {
            SafeTransfers.transferInto(address(token1), address(pool), uint256(-amount1Delta));
        }
        data;
    }

    function mintAndApprove() internal {
        tokenIn.mint(msg.sender, 100000000000 ether);
        tokenOut.mint(msg.sender, 100000000000 ether);
        tokenIn.mint(address(this), 100000000000 ether);
        tokenOut.mint(address(this), 100000000000 ether);
        tokenIn.approve(address(pool), type(uint256).max);
        tokenOut.approve(address(pool), type(uint256).max);
    }

    function _between(uint128 val, uint low, uint high) internal pure returns(uint128) {
        return uint128(low + (val % (high-low +1))); 
    }

    function liquidityMintedBackcalculates(uint128 amount, bool zeroForOne, int24 lower, int24 upper) tickPreconditions(lower, upper) internal {
        // NOTE: Do not use the exact inputs of this function for POCs, use the inputs after the input validation
        amount = amount + 1e5 + 1;
        PoolsharkStructs.CoverImmutables memory immutables = pool.immutables();
        uint256 priceLower = ConstantProduct.getPriceAtTick(lower, immutables);
        uint256 priceUpper = ConstantProduct.getPriceAtTick(upper, immutables);

        uint256 liquidityMinted = ConstantProduct.getLiquidityForAmounts(
            priceLower,
            priceUpper,
            zeroForOne ? priceLower : priceUpper,
            zeroForOne ? 0 : uint256(amount),
            zeroForOne ? uint256(amount) : 0
        );

        (uint256 token0Amount, uint256 token1Amount) = ConstantProduct.getAmountsForLiquidity(
            priceLower,
            priceUpper,
            zeroForOne ? priceLower : priceUpper,
            liquidityMinted,
            true
        );

        if(zeroForOne) {
            emit LiquidityMinted(amount, token0Amount, zeroForOne);
            assert(token0Amount <= amount);
            
        }
        else {
            emit LiquidityMinted(amount, token1Amount, zeroForOne);
            assert(token1Amount <= amount);
        }
    }

    function getTick(
        int24 tickIdx
    ) internal view returns (
        CoverPoolStructs.Tick memory tick
    ) {
        (
            tick.deltas0,
            tick.deltas1,
            tick.liquidityDelta,
            tick.amountInDeltaMaxMinus,
            tick.amountOutDeltaMaxMinus,
            tick.amountInDeltaMaxStashed,
            tick.amountOutDeltaMaxStashed,
            tick.pool0Stash
        ) = pool.ticks(tickIdx);
    }

    function getPoolState(
        bool isPool0
    ) internal view returns (
        CoverPoolStructs.PoolState memory poolState
    ) {
        (
            poolState.price,
            poolState.liquidity,
            poolState.amountInDelta,
            poolState.amountInDeltaMaxClaimed,
            poolState.amountOutDeltaMaxClaimed
        ) = isPool0 ? pool.pool0()
                    : pool.pool1();
    }


    function getGlobalState(
    ) internal view returns (
        CoverPoolStructs.GlobalState memory state
    ) {
        state = pool.getGlobalState();
    }
}