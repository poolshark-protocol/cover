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

        uint128 amountInDeltaMaxMinusUpperBefore;
        uint128 amountInDeltaMaxMinusLowerBefore;
        uint128 amountInDeltaMaxMinusUpperAfter;
        uint128 amountInDeltaMaxMinusLowerAfter;

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
        poolStructs.pool0 = pool.pool0();
        poolStructs.pool1 = pool.pool1();
        poolStructs.globalStateBefore = pool.globalState();

        // pool price and liquidity
        poolValues.price0Before = poolStructs.pool0.price;
        poolValues.liquidity0Before = poolStructs.pool0.liquidity;
        poolValues.price1Before = poolStructs.pool1.price;
        poolValues.liquidity1Before = poolStructs.pool1.liquidity;
                
        // liquidity global
        poolValues.liquidtyGlobalBefore = poolStructs.globalState.liquidityGlobal;

        // position id next
        poolValues.positionIdNextBefore = poolStructs.globalStateBefore.positionIdNext;

        poolStructs.lower = pool.ticks(lower);
        poolStructs.upper = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = poolStructs.upper.amountInDeltaMaxMinus;

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
        emit PositionTicks(lower, upper);
        emit PositionCreated(posCreated);

        // ACTION 
        pool.mintCover(params);
        if (posCreated) positions.push(Position(msg.sender, poolValues.positionIdNextBefore, lower, upper, zeroForOne));

        (, poolStructs.lower) = pool.ticks(lower);
        (, poolStructs.upper) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerAfter = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = poolStructs.upper.amountInDeltaMaxMinus;

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;

        (, poolStructs.pool0, poolStructs.pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        poolValues.price0After = poolStructs.pool0.price;
        poolValues.liquidity0After = poolStructs.pool0.liquidity;
        poolValues.price1After = poolStructs.pool1.price;
        poolValues.liquidity1After = poolStructs.pool1.liquidity;
        poolValues.price0 = poolStructs.pool0.price;
        poolValues.price1 = poolStructs.pool1.price;
        
        // POST CONDITIONS
        emit Prices(poolValues.price0, poolValues.price1);
        assert(poolValues.price0 >= poolValues.price1);
        // Ensure prices have not crossed
        emit Prices(poolValues.price0After, poolValues.price1After);
        assert(poolValues.price0After >= poolValues.price1After);

        // Ensure liquidityDelta is always less or equal to amountInDeltaMaxMinus
        emit LiquidityDeltaAndDeltaMaxMinus(values.liquidityDeltaLowerAfter, poolValues.amountInDeltaMaxMinusLowerAfter);
        assert(int256(values.liquidityDeltaLowerAfter) <= int256(uint256(poolValues.amountInDeltaMaxMinusLowerAfter)));
        emit LiquidityDeltaAndDeltaMaxMinus(values.liquidityDeltaUpperAfter, poolValues.amountInDeltaMaxMinusUpperAfter);
        assert(int256(values.liquidityDeltaUpperAfter) <= int256(uint256(poolValues.amountInDeltaMaxMinusUpperAfter)));
        
        // Ensure that amountInDeltaMaxMinus is incremented when not undercutting
        if(zeroForOne){
            if(poolValues.price0After >= poolValues.price0Before){
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusUpperBefore, poolValues.amountInDeltaMaxMinusUpperAfter);
                assert(poolValues.amountInDeltaMaxMinusUpperAfter >= poolValues.amountInDeltaMaxMinusUpperBefore);
            }
        } else {
            if(poolValues.price1Before >= poolValues.price1After){
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusLowerBefore, poolValues.amountInDeltaMaxMinusLowerAfter);
                assert(poolValues.amountInDeltaMaxMinusLowerAfter >= poolValues.amountInDeltaMaxMinusLowerBefore);
            }
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

    function mintVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint96 mintPercent) public tickPreconditions(lower, upper) {
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

        (,poolStructs.pool0, poolStructs.pool1, poolValues.liquidityGlobalBefore,poolValues.positionIdNextBefore,,) = pool.globalState();
        poolValues.price0Before = poolStructs.pool0.price;
        poolValues.liquidity0Before = poolStructs.pool0.liquidity;
        poolValues.price1Before = poolStructs.pool1.price;
        poolValues.liquidity1Before = poolStructs.pool1.liquidity;

        (, poolStructs.lower) = pool.ticks(lower);
        (, poolStructs.upper) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = poolStructs.upper.amountInDeltaMaxMinus;

        ICoverPool.MintParams memory params;
        params.to = msg.sender;
        params.amount = amount;
        params.mintPercent = mintPercent;
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
        pool.mintCover(params);
        if (posCreated) positions.push(Position(msg.sender, poolValues.positionIdNextBefore, lower, upper, zeroForOne));

        (, poolStructs.lower) = pool.ticks(lower);
        (, poolStructs.upper) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerAfter = poolStructs.lower.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = poolStructs.upper.amountInDeltaMaxMinus;

        values.liquidityDeltaLowerAfter = poolStructs.lower.liquidityDelta;
        values.liquidityDeltaUpperAfter = poolStructs.upper.liquidityDelta;

        (, poolStructs.pool0, poolStructs.pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        poolValues.price0After = poolStructs.pool0.price;
        poolValues.liquidity0After = poolStructs.pool0.liquidity;
        poolValues.price1After = poolStructs.pool1.price;
        poolValues.liquidity1After = poolStructs.pool1.liquidity;
        
        poolValues.price0 = poolStructs.pool0.price;
        poolValues.price1 = poolStructs.pool1.price;

        // POST CONDITIONS
        emit Prices(poolValues.price0, poolValues.price1);
        assert(poolValues.price0 >= poolValues.price1);
        emit Prices(poolValues.price0After, poolValues.price1After);

        // Ensure liquidityDelta is always less or equal to amountInDeltaMaxMinus
        emit LiquidityDeltaAndDeltaMaxMinus(values.liquidityDeltaLowerAfter, poolValues.amountInDeltaMaxMinusLowerAfter);
        assert(int256(values.liquidityDeltaLowerAfter) <= int256(uint256(poolValues.amountInDeltaMaxMinusLowerAfter)));
        emit LiquidityDeltaAndDeltaMaxMinus(values.liquidityDeltaUpperAfter, poolValues.amountInDeltaMaxMinusUpperAfter);
        assert(int256(values.liquidityDeltaUpperAfter) <= int256(uint256(poolValues.amountInDeltaMaxMinusUpperAfter)));

        // Ensure that amountInDeltaMaxMinus is incremented when not undercutting
        if(zeroForOne){
            if(poolValues.price0After >= poolValues.price0Before){
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusUpperBefore, poolValues.amountInDeltaMaxMinusUpperAfter);
                assert(poolValues.amountInDeltaMaxMinusUpperAfter > poolValues.amountInDeltaMaxMinusUpperBefore);
            }
        } else {
            if(poolValues.price1Before >= poolValues.price1After){
                emit AmountInDeltaMaxMinus(poolValues.amountInDeltaMaxMinusLowerBefore, poolValues.amountInDeltaMaxMinusLowerAfter);
                assert(poolValues.amountInDeltaMaxMinusLowerAfter > poolValues.amountInDeltaMaxMinusLowerBefore);
            }
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

    function swap(uint160 priceCover, uint128 amount, bool exactIn, bool zeroForOne) public {
        // PRE CONDITIONS
        mintAndApprove();

        CoverPoolStructs.SwapParams memory params;
        params.to = msg.sender;
        params.priceCover = priceCover;
        params.amount = amount;
        params.exactIn = exactIn;
        params.zeroForOne = zeroForOne;
        params.callbackData = abi.encodePacked(address(this));
        
        // ACTION
        pool.swap(params);

        // POST CONDITIONS
        CoverPoolStructs.PoolState memory pool0 = pool.pool0();
        CoverPoolStructs.PoolState memory pool1 = pool.pool1();
        uint160 price0 = pool0.price;
        uint160 price1 = pool1.price;
        
        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 >= price1);
    }

    function burn(int24 claimAt, uint256 positionIndex, uint128 burnPercent) public {
        // PRE CONDITIONS
        positionIndex = positionIndex % positions.length;
        Position memory pos = positions[positionIndex];
        require(claimAt >= pos.lower && claimAt <= pos.upper);
        require(claimAt % tickSpacing == 0);
        PoolValues memory poolValues;

        CoverPoolStructs.PoolState memory pool0 = pool.pool0();
        CoverPoolStructs.PoolState memory pool1 = pool.pool1();
        (,,uint128 liquidityGlobalBefore,,,,,,,,) = pool.globalState();

        ICoverPool.BurnParams memory params;
        params.to = pos.owner;
        params.burnPercent = burnPercent == 1e38 ? burnPercent : _between(burnPercent, 1e36, 1e38); //1e38;
        params.positionId = pos.positionId;
        params.claim = claimAt;
        params.zeroForOne = pos.zeroForOne;

        CoverPoolStructs.Tick memory lowerTick = pool.ticks(pos.lower);
        CoverPoolStructs.Tick memory upperTick = pool.ticks(pos.upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = upperTick.amountInDeltaMaxMinus;
        
        emit PositionTicks(pos.lower, pos.upper);
        (int24 lower, int24 upper, bool positionExists) = pool.getResizedTicksForBurn(params);
        emit BurnTicks(lower, upper, positionExists);

        // ACTION
        pool.burnCover(params);
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

        (, lowerTick) = pool.ticks(lower);
        (, upperTick) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerAfter = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = upperTick.amountInDeltaMaxMinus;

        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0 = pool0.price;
        uint160 price1 = pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 >= price1);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert((poolValues.liquidityGlobalAfter <= liquidityGlobalBefore));
    }

    function claim(int24 claimAt, uint256 positionIndex) public {
        // PRE CONDITIONS
        positionIndex = positionIndex % positions.length;
        Position memory pos = positions[positionIndex];
        claimAt = pos.lower + (claimAt % (pos.upper - pos.lower));
        require(claimAt % tickSpacing == 0);

        PoolValues memory poolValues;
        (,CoverPoolStructs.PoolState memory pool0, CoverPoolStructs.PoolState memory pool1, uint128 liquidityGlobalBefore,,,) = pool.globalState();

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
        pool.burnCover(params);
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
        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0 = pool0.price;
        uint160 price1 = pool1.price;

        // Ensure prices never cross
        emit Prices(price0, price1);
        assert(price0 >= price1);
    }

    function mintThenBurnZeroLiquidityChangeVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint96 mintPercent) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        mintAndApprove();
        PoolValues memory poolValues;
        (,CoverPoolStructs.PoolState memory pool0, CoverPoolStructs.PoolState memory pool1, uint128 liquidityGlobalBefore,,,) = pool.globalState();

        LiquidityDeltaValues memory values;
        (, CoverPoolStructs.Tick memory lowerTick) = pool.ticks(lower);
        (, CoverPoolStructs.Tick memory upperTick) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = upperTick.amountInDeltaMaxMinus;

        // ACTION 
        mintVariable(amount, zeroForOne, lower, upper, mintPercent);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        // POST CONDITIONS
        (, lowerTick) = pool.ticks(lower);
        (, upperTick) = pool.ticks(upper);

        values.liquidityDeltaLowerAfter = lowerTick.liquidityDelta;
        values.liquidityDeltaUpperAfter = upperTick.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerAfter = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = upperTick.amountInDeltaMaxMinus;
        
        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0After = pool0.price;
        uint160 price1After = pool1.price;

        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After >= price1After);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenBurnZeroLiquidityChange(uint128 amount, bool zeroForOne, int24 lower, int24 upper) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        mintAndApprove();
        PoolValues memory poolValues;
        (,CoverPoolStructs.PoolState memory pool0, CoverPoolStructs.PoolState memory pool1, uint128 liquidityGlobalBefore,,,) = pool.globalState();

        LiquidityDeltaValues memory values;
        (, CoverPoolStructs.Tick memory lowerTick) = pool.ticks(lower);
        (, CoverPoolStructs.Tick memory upperTick) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = upperTick.amountInDeltaMaxMinus;

        // ACTION 
        mint(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        (, lowerTick) = pool.ticks(lower);
        (, upperTick) = pool.ticks(upper);

        values.liquidityDeltaLowerAfter = lowerTick.liquidityDelta;
        values.liquidityDeltaUpperAfter = upperTick.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerAfter = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = upperTick.amountInDeltaMaxMinus;


        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0After = pool0.price;
        uint160 price1After = pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After >= price1After);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenPartialBurnTwiceLiquidityChange(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint128 percent) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        percent = 1 + (percent % (1e38 - 1));
        mintAndApprove();
        PoolValues memory poolValues;
        (,CoverPoolStructs.PoolState memory pool0, CoverPoolStructs.PoolState memory pool1, uint128 liquidityGlobalBefore,,,) = pool.globalState();

        LiquidityDeltaValues memory values;
        (, CoverPoolStructs.Tick memory lowerTick) = pool.ticks(lower);
        (, CoverPoolStructs.Tick memory upperTick) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = upperTick.amountInDeltaMaxMinus;

        // ACTION 
        mint(amount, zeroForOne, lower, upper);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, percent);
        emit PassedBurn();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        (, lowerTick) = pool.ticks(lower);
        (, upperTick) = pool.ticks(upper);

        values.liquidityDeltaLowerAfter = lowerTick.liquidityDelta;
        values.liquidityDeltaUpperAfter = upperTick.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerAfter = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = upperTick.amountInDeltaMaxMinus;

        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0After = pool0.price;
        uint160 price1After = pool1.price;

        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After >= price1After);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
    }

    function mintThenPartialBurnTwiceLiquidityChangeVariable(uint128 amount, bool zeroForOne, int24 lower, int24 upper, uint128 percent, uint96 mintPercent) public tickPreconditions(lower, upper) {
        // PRE CONDITIONS
        percent = 1 + (percent % (1e38 - 1));
        mintAndApprove();
        PoolValues memory poolValues;
        (,CoverPoolStructs.PoolState memory pool0, CoverPoolStructs.PoolState memory pool1, uint128 liquidityGlobalBefore,,,) = pool.globalState();

        LiquidityDeltaValues memory values;
        (, CoverPoolStructs.Tick memory lowerTick) = pool.ticks(lower);
        (, CoverPoolStructs.Tick memory upperTick) = pool.ticks(upper);

        poolValues.amountInDeltaMaxMinusLowerBefore = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperBefore = upperTick.amountInDeltaMaxMinus;

        // ACTION 
        mintVariable(amount, zeroForOne, lower, upper, mintPercent);
        emit PassedMint();
        burn(zeroForOne ? lower : upper, positions.length - 1, percent);
        emit PassedBurn();
        burn(zeroForOne ? lower : upper, positions.length - 1, 1e38);
        emit PassedBurn();

        (, lowerTick) = pool.ticks(lower);
        (, upperTick) = pool.ticks(upper);

        values.liquidityDeltaLowerAfter = lowerTick.liquidityDelta;
        values.liquidityDeltaUpperAfter = upperTick.liquidityDelta;
        poolValues.amountInDeltaMaxMinusLowerAfter = lowerTick.amountInDeltaMaxMinus;
        poolValues.amountInDeltaMaxMinusUpperAfter = upperTick.amountInDeltaMaxMinus;

        (,pool0, pool1, poolValues.liquidityGlobalAfter,,,) = pool.globalState();
        uint160 price0After = pool0.price;
        uint160 price1After = pool1.price;
        
        // POST CONDITIONS

        // Ensure prices never cross
        emit Prices(price0After, price1After);
        assert(price0After >= price1After);

        // Ensure liquidityGlobal is decremented after burn
        emit LiquidityGlobal(liquidityGlobalBefore, poolValues.liquidityGlobalAfter);
        assert(poolValues.liquidityGlobalAfter == liquidityGlobalBefore);
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
}