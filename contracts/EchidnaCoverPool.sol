// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import './CoverPool.sol';
import './CoverPoolFactory.sol';
import './utils/CoverPoolManager.sol';
import './test/Token20.sol';
import './libraries/utils/SafeTransfers.sol';
import './interfaces/structs/CoverPoolStructs.sol';
import './interfaces/structs/PoolsharkStructs.sol';
import './test/UniswapV3FactoryMock.sol';
import './libraries/sources/UniswapV3Source.sol';

//TODO: make sure no assertions fail
//TODO: add the ability to change the TWAP randomly

// Fuzz CoverPool functionality
contract EchidnaPool {

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

    int16 tickSpacing;
    uint16 swapFee;
    address private implementation;
    address private poolFactoryMock;
    address private twapSource;
    CoverPoolFactory private factory;
    CoverPoolManager private manager;
    CoverPool private pool;
    Token20 private tokenIn;
    Token20 private tokenOut;
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
    }

    modifier tickPreconditions(int24 lower, int24 upper) {
        require(lower < upper);
        require(upper < 887272);
        require(lower > -887272);
        require(lower % tickSpacing == 0);
        require(upper % tickSpacing == 0);
        _;
    }

    constructor() {
        manager = new CoverPoolManager();
        factory = new CoverPoolFactory(address(manager));
        implementation = address(new CoverPool(address(factory)));
        tokenIn = new Token20("IN", "IN", 18);
        tokenOut = new Token20("OUT", "OUT", 18);
        poolFactoryMock = address(new UniswapV3FactoryMock(address(tokenIn), address(tokenOut)));

        twapSource = address(new UniswapV3Source(poolFactoryMock));
        
        manager.enablePoolType(bytes32(0x0), address(implementation), twapSource);
        tickSpacing = 10;
        ICoverPoolFactory.CoverPoolParams memory params;

        address poolAddr = factory.createCoverPool(params);
        pool = CoverPool(poolAddr);
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

        // tick values
        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;
        poolValues.amountOutDeltaMaxMinusLowerAfter = poolStructs.lower.amountOutDeltaMaxMinus;
        poolValues.amountOutDeltaMaxMinusUpperAfter = poolStructs.upper.amountOutDeltaMaxMinus;
        
        // POST CONDITIONS
        emit Prices(poolValues.price0, poolValues.price1);
        assert(poolValues.price0 >= poolValues.price1);
        // Ensure prices have not crossed
        emit Prices(poolValues.price0After, poolValues.price1After);
        assert(poolValues.price0After >= poolValues.price1After);

        // Ensure amountOutDeltaMaxMinus change is always equal to params.amount
        // NOTE: skip for now because amount can change
        // if (zeroForOne) {
        //     emit amountOutDeltaMaxMinusandAmountIn(params.amount, poolValues.amountOutDeltaMaxMinusLowerBefore, poolValues.amountOutDeltaMaxMinusLowerAfter);
        //     assert(poolValues.amountOutDeltaMaxMinusLowerAfter -  poolValues.amountOutDeltaMaxMinusLowerBefore <= int256(uint256(poolValues.amountOutDeltaMaxMinusLowerAfter)));
        // } else {
        //     emit amountOutDeltaMaxMinusandAmountIn(params.amount, poolValues.amountOutDeltaMaxMinusUpperBefore, poolValues.amountOutDeltaMaxMinusUpperAfter);
        //     assert(poolValues.amountOutDeltaMaxMinusUpperAfter -  poolValues.amountOutDeltaMaxMinusUpperBefore <= int256(uint256(poolValues.amountOutDeltaMaxMinusUpperAfter)));
        // }
        
        // Ensure that amountOutDeltaMaxMinus is incremented when not undercutting
        //NOTE: delta max minus should be strictly greater as both values should be non-zero
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
            assert((lower % tickSpacing == 0) && (upper % tickSpacing == 0));
        }
        
        emit LiquidityGlobal(poolValues.liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        emit Liquidity(poolValues.liquidity0Before, poolValues.liquidity1Before, poolValues.liquidity0After, poolValues.liquidity1After);
        
        // Ensure liquidityGlobal is incremented after mint
        assert(poolValues.liquidityGlobalAfter >= poolValues.liquidityGlobalBefore);
        
        // Ensure pool liquidity is non-zero after mint with no undercuts
        if (zeroForOne) {
            if (poolValues.price0After < poolValues.price0Before) assert(poolValues.liquidity0After > 0);
        }
        else {
            if (poolValues.price1After > poolValues.price1Before) assert(poolValues.liquidity1After > 0);
        }
    }

    function mintVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
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
        emit Prices(poolValues.price0, poolValues.price1);
        assert(poolValues.price0 >= poolValues.price1);
        emit Prices(poolValues.price0After, poolValues.price1After);

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

        // Ensure prices have not crossed
        assert(poolValues.price0After >= poolValues.price1After);
        if (posCreated) {
            emit PositionTicks(lower, upper);
            // Ensure positions ticks arent crossed
            assert(lower < upper);
            // Ensure minted ticks on proper tick spacing
            assert((lower % tickSpacing == 0) && (upper % tickSpacing == 0));
        }
        
        emit LiquidityGlobal(poolValues.liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        emit Liquidity(poolValues.liquidity0Before, poolValues.liquidity1Before, poolValues.liquidity0After, poolValues.liquidity1After);
        
        // Ensure liquidityGlobal is incremented after mint
        assert(poolValues.liquidityGlobalAfter >= poolValues.liquidityGlobalBefore);

        // Ensure pool liquidity is non-zero after mint with no undercuts
        if (zeroForOne) {
            if (poolValues.price0After < poolValues.price0Before) assert(poolValues.liquidity0After > 0);
        }
        else {
            if (poolValues.price1After > poolValues.price1Before) assert(poolValues.liquidity1After > 0);
        }
    }

    function swap(uint160 priceLimit, uint128 amount, bool exactIn, bool zeroForOne) public {
        // PRE CONDITIONS
        mintAndApprove();

        CoverPoolStructs.SwapParams memory params;
        params.to = msg.sender;
        params.priceLimit = priceLimit;
        params.amount = amount;
        params.exactIn = exactIn;
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

    function burn(int24 claimAt, uint256 positionIndex, uint128 burnPercent) public {
        // PRE CONDITIONS
        positionIndex = positionIndex % positions.length;
        Position memory pos = positions[positionIndex];
        require(claimAt >= pos.lower && claimAt <= pos.upper);
        require(claimAt % tickSpacing == 0);
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
            assert((lower % tickSpacing == 0) && (upper % tickSpacing == 0));
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
        require(claimAt % tickSpacing == 0);

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
            assert((lower % tickSpacing == 0) && (upper % tickSpacing == 0));
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
        assert(price0After >= price1After);

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
        assert(price0After >= price1After);

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
        assert(price0After >= price1After);

        // Ensure liquidityGlobal is decremented after burn
        // emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        // assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function poolsharkSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        address token0 = CoverPool(pool).token0();
        address token1 = CoverPool(pool).token1();
        if (amount0Delta < 0) {
            SafeTransfers.transferInto(token0, address(pool), uint256(-amount0Delta));
        } else {
            SafeTransfers.transferInto(token1, address(pool), uint256(-amount1Delta));
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
            tick.amountOutDeltaMaxMinus,
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