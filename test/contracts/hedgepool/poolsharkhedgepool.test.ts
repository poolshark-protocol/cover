/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from 'ethers';
import { mintSigners20 } from '../../utils/token';
import { validateMint, BN_ZERO, validateSwap, validateBurn, Tick, PoolState, TickNode } from '../../utils/contracts/hedgepool/hedgepool';

alice: SignerWithAddress;
describe('PoolsharkHedgePool Basic Tests', function () {

  let token0Amount: BigNumber;
  let token1Amount: BigNumber;
  let token0Decimals: number;
  let token1Decimals: number;
  let currentPrice: BigNumber;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  const liquidityAmount = BigNumber.from('199760153929825488153727');
  const minTickIdx = BigNumber.from('-887272');
  const maxTickIdx = BigNumber.from('887272');

  before(async function () {
    await gBefore();
    let currentBlock = await ethers.provider.getBlockNumber();
    //TODO: maybe just have one view function that grabs all these
    //TODO: map it to an interface
    const pool0: PoolState    = await hre.props.hedgePool.pool0();
    const liquidity           = pool0.liquidity;
    const lastBlockNumber     = pool0.lastBlockNumber;
    const feeGrowthGlobalIn     = pool0.feeGrowthGlobalIn;
    const nearestTick         = pool0.nearestTick;
    const price               = pool0.price;
    const latestTick          = await hre.props.hedgePool.latestTick();

    expect(liquidity).to.be.equal(BN_ZERO);
    expect(lastBlockNumber).to.be.equal(currentBlock);
    expect(feeGrowthGlobalIn).to.be.equal(BN_ZERO);
    expect(latestTick).to.be.equal(BN_ZERO);
    expect(nearestTick).to.be.equal(BN_ZERO);

    // console.log("sqrt price:", await (await hre.props.hedgePool.sqrtPrice()).toString());
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
  //TODO: mint with signer
  it('Should mint new LP position', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    let minTick: TickNode = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      ""
    );
    
    // validate upper and lower ticks
    const lowerTickNode = await hre.props.hedgePool.tickNodes(
      lower
    );
    const lowerTick = await hre.props.hedgePool.ticks1(
      lower
    );
    const upperTickNode = await hre.props.hedgePool.tickNodes(
      upper
    );
    const upperTick = await hre.props.hedgePool.ticks1(
      upper
    );

    expect(lowerTickNode.previousTick).to.be.equal(lowerOld);
    expect(lowerTickNode.nextTick).to.be.equal(upper);
    expect(lowerTick.liquidityDelta).to.be.equal(liquidityAmount);
    expect(lowerTick.liquidityDeltaMinus).to.be.equal(BN_ZERO);

    expect(upperTickNode.previousTick).to.be.equal(lower);
    expect(upperTickNode.nextTick).to.be.equal(upperOld);
    expect(upperTick.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityAmount));
    expect(upperTick.liquidityDeltaMinus).to.be.equal(liquidityAmount);
  });

  it('Should swap with zero output', async function () {
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    let minTick: TickNode = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.hedgePool.tickNodes(maxTickIdx);
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
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    let minTick: TickNode = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
    await validateBurn(
      hre.props.alice,
      lower,
      upper,
      lower,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      ""
    );
  });

  it('Should move TWAP before mint and do a successful swap', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("30", 0);
    const lower    = hre.ethers.utils.parseUnits("60", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("90", 0);
    const burnAmount = hre.ethers.utils.parseUnits("66420461859385355519898", 0);
    let minTick: TickNode = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick: TickNode = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick: TickNode = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
    // move TWAP to tick 50
    let txn = await hre.props.concentratedPoolMock.setTickCumulatives(
      3600,
      1800
    );
    await txn.wait();

    // mint new position
    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      token1Amount,
      false,
      token1Amount,
      burnAmount,
      ""
    );

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
      lower,
      burnAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      ""
    )

    minTick = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    latestTick = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    maxTick = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
  });

  it('Should not mint position with lower below TWAP', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
    const lower    = hre.ethers.utils.parseUnits("0", 0);
    const upperOld = hre.ethers.utils.parseUnits("50", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);

    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      "InvalidPosition()"
    );

    
    let minTick = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());
  });

  it('Should mint, swap, and then claim entire range', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
    const feeTaken = hre.ethers.utils.parseUnits("5", 16);

    let txn = await hre.props.concentratedPoolMock.setTickCumulatives(
      0,
      0
    );
    await txn.wait();

    const lowerOldTickBefore: Tick = await hre.props.hedgePool.ticks1("0");
    console.log('min tick:', lowerOldTickBefore.toString());

    await validateMint(
      hre.props.alice,
      hre.props.alice.address,
      lowerOld,
      lower,
      upperOld,
      upper,
      token1Amount,
      false,
      token1Amount,
      liquidityAmount,
      ""
    );

    
    let minTick = await hre.props.hedgePool.tickNodes(minTickIdx);
    console.log('min tick:', minTick.toString());
    let latestTick = await hre.props.hedgePool.tickNodes(await hre.props.hedgePool.latestTick());
    console.log('latest tick:', latestTick.toString());
    let maxTick = await hre.props.hedgePool.tickNodes(maxTickIdx);
    console.log('max tick:', maxTick.toString());

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
      lower,
      liquidityAmount,
      false,
      BN_ZERO,
      token1Amount.sub(1),
      ""
    )
  });

  it('Should fail on second claim', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());

    await expect(hre.props.hedgePool.burn(
      lower,
      upper,
      upper,
      false,
      liquidityAmount
    )).to.be.revertedWith("NotEnoughPositionLiquidity()");
  });

  // TODO: partial mint
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
  //   const txn = await hre.props.hedgePool.mint(
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
  //   console.log(await hre.props.hedgePool.positions(
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