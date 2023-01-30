/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from 'ethers';
import { mintSigners20 } from '../utils/token';
import { validateMint, BN_ZERO, validateSwap, validateBurn, Tick, PoolState, TickNode, validateSync } from '../utils/contracts/coverpool';
import { ValidateMintParams } from '../utils/contracts/coverpool';

alice: SignerWithAddress;
describe('CoverPool Tests', function () {

  let tokenAmount: BigNumber;
  let token0Decimals: number;
  let token1Decimals: number;
  let minPrice: BigNumber;
  let maxPrice: BigNumber;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  const liquidityAmount = BigNumber.from('99855108194609381495771');
  const minTickIdx = BigNumber.from('-887272');
  const maxTickIdx = BigNumber.from('887272');

  //every test should clear out all liquidity

  before(async function () {
    await gBefore();
    let currentBlock = await ethers.provider.getBlockNumber();
    //TODO: maybe just have one view function that grabs all these
    //TODO: map it to an interface
    const pool0: PoolState      = await hre.props.coverPool.pool0();
    const liquidity             = pool0.liquidity;
    const globalState           = await hre.props.coverPool.globalState();
    const lastBlockNumber       = globalState.lastBlockNumber;
    const feeGrowthCurrentEpoch = pool0.feeGrowthCurrentEpoch;
    const nearestTick           = pool0.nearestTick;
    const price                 = pool0.price;
    const latestTick            = globalState.latestTick;

    expect(liquidity).to.be.equal(BN_ZERO);
    expect(lastBlockNumber).to.be.equal(currentBlock);
    expect(feeGrowthCurrentEpoch).to.be.equal(BN_ZERO);
    expect(latestTick).to.be.equal(BN_ZERO);
    expect(nearestTick).to.be.equal(BN_ZERO);

    minPrice = BigNumber.from("4295128739");
    maxPrice = BigNumber.from("1461446703485210103287273052203988822378723970341");
    token0Decimals = await hre.props.token0.decimals();
    token1Decimals = await hre.props.token1.decimals();
    tokenAmount = ethers.utils.parseUnits("100", token0Decimals);
    tokenAmount = ethers.utils.parseUnits("100", token1Decimals);
    alice = hre.props.alice;
    bob   = hre.props.bob;
    carol = hre.props.carol;
  });

  this.beforeEach(async function () {
    await mintSigners20(
      hre.props.token0,
      tokenAmount.mul(10),
      [hre.props.alice, hre.props.bob]
    )

    await mintSigners20(
      hre.props.token1,
      tokenAmount.mul(10),
      [hre.props.alice, hre.props.bob]
    )

    await hre.props.rangePoolMock.setObservationCardinality("5");
  });

  it('pool0 - Should wait until enough observations', async function () {
    await hre.props.rangePoolMock.setObservationCardinality("4");
    // mint should revert
    await validateMint({
        signer:            hre.props.alice,
        recipient:         hre.props.alice.address,
        lowerOld:          "0",
        lower:             "0",
        upper:             "0",
        upperOld:          "0",
        claim:             "0", 
        amount:            tokenAmount,
        zeroForOne:        true,
        balanceInDecrease: tokenAmount,
        liquidityIncrease: liquidityAmount,
        upperTickCleared:  false,
        lowerTickCleared:  false,
        revertMessage: "WaitUntilEnoughObservations()",
        collectRevertMessage: "WaitUntilEnoughObservations()"
    });

    // no-op swap
    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         false,
      amountIn:           tokenAmount,
      sqrtPriceLimitX96:  minPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      "WaitUntilEnoughObservations()"
    });

    // burn should revert
    await validateBurn({
      signer:             hre.props.alice,
      lower:              "0",
      upper:              "0",
      claim:              "0",
      liquidityAmount:    liquidityAmount,
      zeroForOne:         true,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(1),
      lowerTickCleared:   false,
      upperTickCleared:   false,
      revertMessage:      "WaitUntilEnoughObservations()"
    });
  });

  it('pool1 - Should wait until enough observations', async function () {
    await hre.props.rangePoolMock.setObservationCardinality("4");
    // mint should revert
    await validateMint({
        signer:            hre.props.alice,
        recipient:         hre.props.alice.address,
        lowerOld:          "0",
        lower:             "0",
        upper:             "0",
        upperOld:          "0",
        claim:             "0", 
        amount:            tokenAmount,
        zeroForOne:        false,
        balanceInDecrease: tokenAmount,
        liquidityIncrease: liquidityAmount,
        upperTickCleared:  false,
        lowerTickCleared:  false,
        revertMessage: "WaitUntilEnoughObservations()",
        collectRevertMessage: "WaitUntilEnoughObservations()"
    });

    // no-op swap
    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         true,
      amountIn:           tokenAmount,
      sqrtPriceLimitX96:  minPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      "WaitUntilEnoughObservations()"
    });

    // burn should revert
    await validateBurn({
      signer:             hre.props.alice,
      lower:              "0",
      upper:              "0",
      claim:              "0",
      liquidityAmount:    liquidityAmount,
      zeroForOne:         false,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(1),
      lowerTickCleared:   false,
      upperTickCleared:   false,
      revertMessage:      "WaitUntilEnoughObservations()"
    });
  });

  it('pool0 - Should mint/burn new LP position', async function () {

    // process two mints
    for(let i = 0;i<2;i++) {
      await validateMint({
        signer:       hre.props.alice,
        recipient:    hre.props.alice.address,
        lowerOld:     "-887272",
        lower:        "-40",
        claim:        "-20",
        upper:        "-20",
        upperOld:     "0",
        amount:       tokenAmount,
        zeroForOne:   true,
        balanceInDecrease: tokenAmount,
        liquidityIncrease: liquidityAmount,
        upperTickCleared: false,
        lowerTickCleared: false,
        revertMessage: ""
      });
    }

    // process no-op swap
    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         false,
      amountIn:           tokenAmount,
      sqrtPriceLimitX96:  maxPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         maxPrice,
      revertMessage:      ""
    })

    // process two burns
    for(let i = 0;i<2;i++) {
      await validateBurn({
        signer:             hre.props.alice,
        lower:              "-40",
        claim:              "-20",
        upper:              "-20",
        liquidityAmount:    liquidityAmount,
        zeroForOne:         true,
        balanceInIncrease:  BN_ZERO,
        balanceOutIncrease: tokenAmount.sub(1),
        lowerTickCleared:   false,
        upperTickCleared:   false,
        revertMessage:      ""
      });
    }
    // validate upper and lower ticks
    //TODO: move to validate mint/burn
    const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
    const lower    = hre.ethers.utils.parseUnits("-40", 0);
    const upper    = hre.ethers.utils.parseUnits("-20", 0);

    const lowerTickNode = await hre.props.coverPool.tickNodes(
      lower
    );
    const upperTickNode = await hre.props.coverPool.tickNodes(
      upper
    );
    expect(lowerTickNode.previousTick.toString()).to.be.equal("-887272");
    expect(lowerTickNode.nextTick.toString()).to.be.equal("-20");
    expect(upperTickNode.previousTick.toString()).to.be.equal("-40");
    expect(upperTickNode.nextTick.toString()).to.be.equal("0");
  });

  it('pool0 - Should revert if tick not divisible by tickSpread', async function () {
     
    // move TWAP to tick 0
    await validateSync(
      hre.props.admin,
      "0"
    );

    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "-887272",
      lower:        "-30",
      claim:        "-20",
      upper:        "-20",
      upperOld:     "0",
      amount:       tokenAmount,
      zeroForOne:   true,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: "InvalidLowerTick()"
    });

    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "-887272",
      lower:        "-40",
      claim:        "-10",
      upper:        "-10",
      upperOld:     "0",
      amount:       tokenAmount,
      zeroForOne:   true,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: "InvalidUpperTick()"
    });

   
  });

  it('pool0 - Should swap with zero output', async function () {
    // move TWAP to tick 0
    await validateSync(
      hre.props.admin,
      "0"
    );

    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "-887272",
      lower:        "-40",
      claim:        "-20",
      upper:        "-20",
      upperOld:     "0",
      amount:       tokenAmount,
      zeroForOne:   true,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: ""
    });

    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         false,
      amountIn:           tokenAmount.div(10),
      sqrtPriceLimitX96:  maxPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      ""
    });

    await validateBurn({
      signer:             hre.props.alice,
      lower:              "-40",
      claim:              "-20",
      upper:              "-20",
      liquidityAmount:    liquidityAmount,
      zeroForOne:         true,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(1),
      lowerTickCleared:   false,
      upperTickCleared:   false,
      revertMessage:      ""
    });
  });

  // move TWAP in range; no-op swap; burn immediately

  // move TWAP in range; no-op swap; move TWAP down tickSpread; burn liquidity

  // move TWAP in range; no-op swap; move TWAP down tickSpread; mint liquidity; burn liquidity

  // move TWAP in range; swap full amount; burn liquidity

  // move TWAP in range; swap full amount; mint liquidity; burn liquidity

  // move TWAP in range; swap partial amount; burn liquidity

  // move TWAP in range; swap partial amount; mint liquidity; burn liquidity

  // move TWAP and skip entire range; burn liquidity

  // move TWAP and skip entire range; mint more liquidity; burn liquidity

  // move TWAP and skip entire range; move TWAP back; burn liquidity

  // move TWAP and skip entire range; move TWAP back; mint liquidity; burn liquidity

  // move TWAP to unlock liquidity; partial fill; move TWAP down

  it('pool1 - Should mint/burn new LP position', async function () {

    // process two mints
    for(let i = 0;i<2;i++) {
      await validateMint({
        signer:       hre.props.alice,
        recipient:    hre.props.alice.address,
        lowerOld:     "0",
        lower:        "20",
        claim:        "20",
        upper:        "40",
        upperOld:     "887272",
        amount:       tokenAmount,
        zeroForOne:   false,
        balanceInDecrease: tokenAmount,
        liquidityIncrease: liquidityAmount,
        upperTickCleared: false,
        lowerTickCleared: false,
        revertMessage: ""
      });
    }
    
    // process no-op swap
    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         true,
      amountIn:           tokenAmount,
      sqrtPriceLimitX96:  maxPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      ""
    })
    
    // process two burns
    for(let i = 0;i<2;i++) {
      await validateBurn({
        signer:             hre.props.alice,
        lower:              "20",
        claim:              "20",
        upper:              "40",
        liquidityAmount:    liquidityAmount,
        zeroForOne:         false,
        balanceInIncrease:  BN_ZERO,
        balanceOutIncrease: tokenAmount.sub(1),
        lowerTickCleared:   false,
        upperTickCleared:   false,
        revertMessage:      ""
      });
    }
  });

  it('pool1 - Should swap with zero output', async function () {
    // move TWAP to tick 0
    await validateSync(
      hre.props.admin,
      "0"
    );

    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "0",
      lower:        "20",
      claim:        "20",
      upper:        "40",
      upperOld:     "887272",
      amount:       tokenAmount,
      zeroForOne:   false,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage:    ""
    });

    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         true,
      amountIn:           tokenAmount.div(10),
      sqrtPriceLimitX96:  minPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      ""
    });

    await validateBurn({
      signer:             hre.props.alice,
      lower:              "20",
      claim:              "20",
      upper:              "40",
      liquidityAmount:    liquidityAmount,
      zeroForOne:         false,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(1),
      lowerTickCleared:   false,
      upperTickCleared:   false,
      revertMessage:      ""
    });
  });


  it('pool1 - Should move TWAP after mint and handle unfilled amount', async function () {
    const liquidityAmount2 = hre.ethers.utils.parseUnits("99955008249587388643769", 0);
    const balanceInDecrease = hre.ethers.utils.parseUnits("99750339674246044929", 0);
    const balanceOutIncrease = hre.ethers.utils.parseUnits("99999999999999999999", 0);

    // move TWAP to tick -20
    await validateSync(
      hre.props.alice,
      "-20"
    );

    // mint position
    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "-20",
      lower:        "0",
      claim:        "0",
      upper:        "20",
      upperOld:     "887272",
      amount:       tokenAmount,
      zeroForOne:   false,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount2,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: ""
    });

    // move TWAP to tick 20
    //TODO: fix infinite loop HERE
    await validateSync(
      hre.props.alice,
      "20"
    );

    // should revert on twap bounds
    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "0",
      lower:        "20",
      claim:        "20",
      upper:        "40",
      upperOld:     "887272",
      amount:       tokenAmount,
      zeroForOne:   false,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: "InvalidPositionBoundsTwap()"
    });

    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         true,
      amountIn:           tokenAmount,
      sqrtPriceLimitX96:  minPrice,
      balanceInDecrease:  BN_ZERO,
      balanceOutIncrease: BN_ZERO,
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      ""
    });

    //burn should revert
    await validateBurn({
      signer:             hre.props.alice,
      lower:              "20",
      claim:              "40",
      upper:              "40",
      liquidityAmount:    liquidityAmount2,
      zeroForOne:         false,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(1),
      lowerTickCleared:   true,
      upperTickCleared:   true,
      revertMessage:      "NotEnoughPositionLiquidity()"
    });

    //valid burn
    await validateBurn({
      signer:             hre.props.alice,
      lower:              "0",
      claim:              "20",
      upper:              "20",
      liquidityAmount:    liquidityAmount2,
      zeroForOne:         false,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount.sub(2),
      lowerTickCleared:   true,
      upperTickCleared:   true,
      revertMessage:      ""
    });
  });

  it('pool1 - Should not mint position below TWAP', async function () {

    await validateSync(
      hre.props.alice,
      "40"
    );

    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "0",
      lower:        "20",
      claim:        "20",
      upper:        "40",
      upperOld:     "887272",
      amount:       tokenAmount,
      zeroForOne:   false,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: "InvalidPositionBoundsTwap()"
    });
  });

  it('Should mint, swap, and then claim entire range', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
    const feeTaken = hre.ethers.utils.parseUnits("5", 16);

    await validateSync(
      hre.props.alice,
      "0"
    );

    //TODO: this reverts as expected but somehow not caught
    // await validateMint(
    //   hre.props.alice,
    //   hre.props.alice.address,
    //   lowerOld,
    //   lower,
    //   upperOld,
    //   upper,
    //   lower,
    //   tokenAmount,
    //   false,
    //   tokenAmount,
    //   liquidityAmount,
    //   true,
    //   false,
    //   "WrongTickClaimedAt()"
    // );
    // // TODO: should lower tick be cleared and upper not be cleared?
    await validateMint({
      signer:       hre.props.alice,
      recipient:    hre.props.alice.address,
      lowerOld:     "0",
      lower:        "20",
      claim:        "20",
      upper:        "40",
      upperOld:     "887272",
      amount:       tokenAmount,
      zeroForOne:   false,
      balanceInDecrease: tokenAmount,
      liquidityIncrease: liquidityAmount,
      upperTickCleared: false,
      lowerTickCleared: false,
      revertMessage: ""
    });

    await validateSync(
      hre.props.alice,
      "20"
    );
    // console.log('before swap')
    // // let minTick = await hre.props.coverPool.tickNodes(minTickIdx);
    // // console.log('min tick:', minTick.toString());
    // // let latestTick = await hre.props.coverPool.tickNodes(await hre.props.coverPool.latestTick());
    // // console.log('latest tick:', latestTick.toString());
    // // let maxTick = await hre.props.coverPool.tickNodes(maxTickIdx);
    // // console.log('max tick:', maxTick.toString());

    await validateSwap({
      signer:             hre.props.alice,
      recipient:          hre.props.alice.address,
      zeroForOne:         true,
      amountIn:           tokenAmount.mul(2),
      sqrtPriceLimitX96:  minPrice,
      balanceInDecrease:  BigNumber.from("99750339674246044929"),
      balanceOutIncrease: BigNumber.from("99999999999999999999"),
      finalLiquidity:     BN_ZERO,
      finalPrice:         minPrice,
      revertMessage:      ""
    });
    // console.log('before burn')
    //TODO: reverts as expected but not caught
    await validateBurn({
      signer:             hre.props.alice,
      lower:              "20",
      claim:              "40",
      upper:              "40",
      liquidityAmount:    liquidityAmount,
      zeroForOne:         false,
      balanceInIncrease:  BN_ZERO,
      balanceOutIncrease: tokenAmount,
      lowerTickCleared:   false,
      upperTickCleared:   false,
      revertMessage:      "WrongTickClaimedAt()"
    })

    // await validateBurn({
    //   signer:             hre.props.alice,
    //   lower:              "20",
    //   claim:              "20",
    //   upper:              "40",
    //   liquidityAmount:    liquidityAmount,
    //   zeroForOne:         false,
    //   balanceInIncrease:  BN_ZERO,
    //   balanceOutIncrease: tokenAmount,
    //   lowerTickCleared:   false,
    //   upperTickCleared:   false,
    //   revertMessage:      "NotImplementedYet()"
    // })
    // 99999999999999999999
    // 99850134913545280154
    // console.log('before burn2')
    // await validateBurn(
    //   hre.props.alice,
    //   lower,
    //   upper,
    //   lower,
    //   liquidityAmount,
    //   false,
    //   BN_ZERO,
    //   tokenAmount.sub(1),
    //   false,
    //   false,
    //   ""
    // )
  });

  // //TODO: these revert catches no longer work inside a library
  // it('Should fail on second claim', async function () {
  //   const lowerOld = hre.ethers.utils.parseUnits("0", 0);
  //   const lower    = hre.ethers.utils.parseUnits("20", 0);
  //   const upperOld = hre.ethers.utils.parseUnits("887272", 0);
  //   const upper    = hre.ethers.utils.parseUnits("40", 0);
  //   const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());

  //   await validateBurn(
  //     hre.props.alice,
  //     lower,
  //     upper,
  //     upper,
  //     BN_ZERO,
  //     false,
  //     BN_ZERO,
  //     BN_ZERO,
  //     true,
  //     true,
  //     ""
  //   )
  // });

  // TODO: partial mint
  // TODO: ensure user cannot claim from a lower tick after TWAP moves around
  // TODO: claim liquidity filled
  // TODO: empty swap at price limit higher than current price
  // TODO: move TWAP again and fill remaining
  // TODO: claim final amount and burn LP position
  // TODO: mint LP position with priceLower < minPrice
  // TODO: P1 larger range; P2 smaller range; execute swap and validate amount returned by claiming
  // TODO: smaller range claims first; larger range claims first
  // TODO: move TWAP down and allow for new positions to be entered
  // TODO: no one can mint until observations are sufficient
  // TODO: fill tick, move TWAP down, claim, move TWAP higher, fill again, claim again

  // mint at different price ranges
  // mint then burn at different price ranges
  // mint swap then burn
  // collect
  //TODO: for price you can mint position instead of swapping and having a failed transaction
})