/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from 'ethers';
import { mintSigners20 } from '../utils/token';
import { validateMint, BN_ZERO, validateSwap, validateBurn, Tick, PoolState, TickNode, validateSync } from '../utils/contracts/coverpool';

alice: SignerWithAddress;
describe('CoverPool Basic Tests', function () {

  let token0Amount: BigNumber;
  let token1Amount: BigNumber;
  let token0Decimals: number;
  let token1Decimals: number;
  let currentPrice: BigNumber;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  const liquidityAmount = BigNumber.from('99855108194609381495771');
  const minTickIdx = BigNumber.from('-887272');
  const maxTickIdx = BigNumber.from('887272');

  //TODO: mint position and burn as if there were 100

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

    // console.log("sqrt price:", await (await hre.props.coverPool.sqrtPrice()).toString());
    currentPrice = price;
    token0Decimals = await hre.props.token0.decimals();
    token1Decimals = await hre.props.token1.decimals();
    token0Amount = ethers.utils.parseUnits("100", token0Decimals);
    token1Amount = ethers.utils.parseUnits("100", token1Decimals);
    alice = hre.props.alice;
    bob   = hre.props.bob;
    carol = hre.props.carol;

    await mintSigners20(
      hre.props.token0,
      token0Amount.mul(10),
      [hre.props.alice, hre.props.bob]
    )

    await mintSigners20(
      hre.props.token1,
      token1Amount.mul(10),
      [hre.props.alice, hre.props.bob]
    )
  });

  this.beforeEach(async function () {

  });

  it('Should mint new LP position', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);
    let minTick: TickNode = await hre.props.coverPool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.coverPool.tickNodes((await hre.props.coverPool.globalState()).latestTick);
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.coverPool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      false,
      false,
      ""
    );

    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      false,
      false,
      ""
    );
    
    // validate upper and lower ticks
    const lowerTickNode = await hre.props.coverPool.tickNodes(
      lower
    );
    const lowerTick = await hre.props.coverPool.ticks1(
      lower
    );
    const upperTickNode = await hre.props.coverPool.tickNodes(
      upper
    );
    const upperTick = await hre.props.coverPool.ticks1(
      upper
    );

    expect(lowerTickNode.previousTick).to.be.equal(lowerOld);
    expect(lowerTickNode.nextTick).to.be.equal(upper);
    expect(lowerTick.liquidityDelta).to.be.equal(liquidityAmount.mul(2));
    expect(lowerTick.liquidityDeltaMinus).to.be.equal(BN_ZERO);

    expect(upperTickNode.previousTick).to.be.equal(lower);
    expect(upperTickNode.nextTick).to.be.equal(upperOld);
    expect(upperTick.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityAmount.mul(2)));
    expect(upperTick.liquidityDeltaMinus).to.be.equal(liquidityAmount.mul(2));
  });

  it('Should not mint new LP position due to tickSpread divisibility', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      false,
      false,
      "InvalidUpperTick()"
    );
  });

  it('Should swap with zero output', async function () {
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    let minTick: TickNode = await hre.props.coverPool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.coverPool.tickNodes((await hre.props.coverPool.globalState()).latestTick);
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.coverPool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
    await validateSwap(
      hre.props.alice,
      hre.props.alice.address,
      true,
      token0Amount.div(10),
      currentPrice,
      BN_ZERO,
      BN_ZERO,
      BN_ZERO,
      currentPrice
    )
  });

  it('Should burn LP position and withdraw all liquidity', async function () {
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    let minTick: TickNode = await hre.props.coverPool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.coverPool.tickNodes((await hre.props.coverPool.globalState()).latestTick);
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.coverPool.tickNodes(60);
    console.log('next tick:', maxTick.toString());
    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      lower,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      false,
      false,
      ""
    );
  });

  it('Should move TWAP before mint and do a successful swap', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("40", 0);
    const lower    = hre.ethers.utils.parseUnits("60", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("100", 0);
    const burnAmount = hre.ethers.utils.parseUnits("49802891105937278098768", 0);
    const balanceInDecrease = hre.ethers.utils.parseUnits("99750339674246044929", 0);
    const balanceOutIncrease = hre.ethers.utils.parseUnits("99999999999999999999", 0);
    let minTick: TickNode = await hre.props.coverPool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.coverPool.tickNodes((await hre.props.coverPool.globalState()).latestTick);
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.coverPool.tickNodes(60);
    console.log('next tick:', maxTick.toString());
    // move TWAP to tick 40
    await validateSync(
      hre.props.alice,
      40
    );
    // mint new position
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      burnAmount,
      false,
      false,
      ""
    );

    await validateSwap(
      hre.props.alice,
      hre.props.alice.address,
      true,
      token0Amount,
      currentPrice,
      balanceInDecrease,
      balanceOutIncrease,
      BN_ZERO,
      currentPrice
    )

    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      lower,
      burnAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      false,
      false,
      ""
    )

    // minTick = await hre.props.coverPool.tickNodes(minTickIdx);
    // console.log('min tick:', minTick.toString());
    // latestTick = await hre.props.coverPool.tickNodes(await hre.props.coverPool.latestTick());
    // console.log('latest tick:', latestTick.toString());
    // maxTick = await hre.props.coverPool.tickNodes(maxTickIdx);
    // console.log('max tick:', maxTick.toString());
  });

  it('Should not mint position with lower below TWAP', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
    const lower    = hre.ethers.utils.parseUnits("0", 0);
    const upperOld = hre.ethers.utils.parseUnits("50", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);

    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      false,
      false,
      "InvalidPositionBoundsTwap()"
    );

    let minTick = await hre.props.coverPool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick = await hre.props.coverPool.tickNodes((await hre.props.coverPool.globalState()).latestTick);
    console.log('latest tick:', latestTick.toString());
    let maxTick = await hre.props.coverPool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
  });

  it('Should mint, swap, and then claim entire range', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
    const feeTaken = hre.ethers.utils.parseUnits("5", 16);

    let txn = await hre.props.rangePoolMock.setTickCumulatives(
      0,
      0
    );
    await txn.wait();

    const lowerOldTickBefore: Tick = await hre.props.coverPool.ticks1("30");
    console.log('upper before tick:', lowerOldTickBefore.toString());

    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      lower,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      true,
      false,
      "WrongTickClaimedAt()"
    );
    // TODO: should lower tick be cleared and upper not be cleared?
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      upper,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      false,
      true,
      ""
    );

    // let minTick = await hre.props.coverPool.tickNodes(minTickIdx);
    // console.log('min tick:', minTick.toString());
    // let latestTick = await hre.props.coverPool.tickNodes(await hre.props.coverPool.latestTick());
    // console.log('latest tick:', latestTick.toString());
    // let maxTick = await hre.props.coverPool.tickNodes(maxTickIdx);
    // console.log('max tick:', maxTick.toString());

    await validateSwap(
      hre.props.alice,
      hre.props.alice.address,
      true,
      token0Amount,
      currentPrice,
      BN_ZERO,
      BN_ZERO,
      BN_ZERO,
      currentPrice
    )

    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      upper,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount,
      false,
      false,
      "WrongTickClaimedAt()"
    )

    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      lower,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      false,
      false,
      ""
    )
  });

  it('Should fail on second claim', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("40", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());

    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      lower,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      true,
      true,
      "NotEnoughPositionLiquidity()"
    )
  });

  // TODO: partial mint
  // TODO: ensure user cannot claim from a lower tick after TWAP moves around
  // TODO: claim liquidity filled
  // TODO: empty swap at price limit higher than current price
  // TODO: move TWAP again and fill remaining
  // TODO: claim final amount and burn LP position
  // TODO: mint LP position with priceLower < currentPrice
  // TODO: P1 larger range; P2 smaller range; execute swap and validate amount returned by claiming
  // TODO: smaller range claims first; larger range claims first
  // TODO: move TWAP down and allow for new positions to be entered
  // TODO: no one can mint until observations are sufficient
  // TODO: fill tick, move TWAP down, claim, move TWAP higher, fill again, claim again

  // it('Should mint new LP position swap and then claim', async function () {
  //   const lowerOld = hre.ethers.utils.parseUnits("0", 0);
  //   const lower    = hre.ethers.utils.parseUnits("20", 0);
  //   const upperOld = hre.ethers.utils.parseUnits("887272", 0);
  //   const upper    = hre.ethers.utils.parseUnits("30", 0);
  //   const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
  //   const txn = await hre.props.coverPool.mint(
  //     {
  //       lowerOld: lowerOld,
  //       lower: lower,
  //       upperOld: upperOld,
  //       upper: upper,
  //       amountDesired: amount,
  //       zeroForOne: false,
  //       native: false
  //     }
  //   );
  //   await txn.wait();
  //   console.log(await hre.props.coverPool.positions(
  //     hre.props.alice.address,
  //     lower,
  //     upper
  //   ));
  //   // validateMint(

  //   // )
  // });

  // mint at different price ranges
  // mint then burn at different price ranges
  // mint swap then burn
  // collect
})