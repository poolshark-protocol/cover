/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { hrtime } from "process";
import { BigNumber } from 'ethers';
import { gasUsed } from '../../utils/blocks';
import { TEXT_COLOR } from '../../utils/colors';
import { mintSigners20 } from '../../utils/token';
import { validateMint, Position, Q64x96, BN_ZERO } from '../../utils/contracts/hedgepool/hedgepool';

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

  before(async function () {
    await gBefore();
    let currentBlock = await ethers.provider.getBlockNumber();
    //TODO: maybe just have one view function that grabs all these
    //TODO: map it to an interface
    const liquidity           = await hre.props.hedgePool.liquidity();
    const secondsGrowthGlobal = await hre.props.hedgePool.secondsGrowthGlobal();
    const lastBlockNumber     = await hre.props.hedgePool.lastBlockNumber();
    const feeGrowthGlobal     = await hre.props.hedgePool.feeGrowthGlobal();
    const feeGrowthGlobalLast = await hre.props.hedgePool.feeGrowthGlobalLast();
    const latestTick          = await hre.props.hedgePool.latestTick();
    const nearestTick         = await hre.props.hedgePool.nearestTick();

    expect(liquidity).to.be.equal(BN_ZERO);
    expect(secondsGrowthGlobal).to.be.equal(BN_ZERO);
    expect(lastBlockNumber).to.be.equal(currentBlock);
    expect(feeGrowthGlobal).to.be.equal(BN_ZERO);
    expect(feeGrowthGlobalLast).to.be.equal(BN_ZERO);
    expect(latestTick).to.be.equal(BN_ZERO);
    expect(nearestTick).to.be.equal(BN_ZERO);

    console.log("sqrt price:", await (await hre.props.hedgePool.sqrtPrice()).toString());

    currentPrice = await hre.props.hedgePool.sqrtPrice();


    // const tickSpacing = (await pool.getImmutables())._tickSpacing;
    // const tickAtPrice = await getTickAtCurrentPrice(pool);
    // const nearestValidTick = tickAtPrice - (tickAtPrice % tickSpacing);
    // const nearestEvenValidTick =
    //   (nearestValidTick / tickSpacing) % 2 == 0 ? nearestValidTick : nearestValidTick + tickSpacing;
  });

  this.beforeEach(async function () {

    token0Decimals = 18;
    token1Decimals = 18;
    token0Amount = ethers.utils.parseUnits("100", token0Decimals);
    token1Amount = ethers.utils.parseUnits("100", token1Decimals);
    // limitPrice   = ethers.utils.parseUnits("80", token1Decimals);
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

  it('Should mint new LP position', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
    const liquidityAmount = BigNumber.from('200260154054812998151852');
    
    const txn = await hre.props.hedgePool.mint(
      {
        lowerOld: lowerOld,
        lower: lower,
        upperOld: upperOld,
        upper: upper,
        amountDesired: amount,
        zeroForOne: false,
        native: false
      }
    );
    await txn.wait();
    // validate position
    const position: Position = await hre.props.hedgePool.positions(
      hre.props.alice.address,
      lower,
      upper
    );
    //TODO: add math to validate liquidity amount
    expect(position.liquidity).to.be.equal(
      liquidityAmount
    );
    
    // validate upper and lower ticks
    const lowerTick = await hre.props.hedgePool.ticks(
      lower
    );
    const upperTick = await hre.props.hedgePool.ticks(
      upper
    );
    console.log("lower", lowerTick.toString());
    console.log("upper:", upperTick.toString());

    expect(lowerTick.previousTick).to.be.equal(lowerOld);
    expect(lowerTick.nextTick).to.be.equal(upper);
    expect(lowerTick.amountIn).to.be.equal(BN_ZERO);
    expect(lowerTick.amountOut).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowthLast).to.be.equal(BN_ZERO);
    expect(lowerTick.liquidity).to.be.equal(liquidityAmount);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);

    expect(upperTick.previousTick).to.be.equal(lower);
    expect(upperTick.nextTick).to.be.equal(upperOld);
    expect(upperTick.amountIn).to.be.equal(BN_ZERO);
    expect(upperTick.amountOut).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowthLast).to.be.equal(BN_ZERO);
    expect(upperTick.liquidity).to.be.equal(liquidityAmount);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
  });

  it('Should allow swap', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());
    const liquidityAmount = BigNumber.from('200260154054812998151852');
    
    let txn = await hre.props.hedgePool.swap(
      hre.props.alice.address,
      true,
      token0Amount.div(10),
      currentPrice
    );
    // validate upper and lower ticks
    const lowerTick = await hre.props.hedgePool.ticks(
      lower
    );
    const upperTick = await hre.props.hedgePool.ticks(
      upper
    );
    console.log("lower", lowerTick.toString());
    console.log("upper:", upperTick.toString());

    expect(lowerTick.previousTick).to.be.equal(lowerOld);
    expect(lowerTick.nextTick).to.be.equal(upper);
    expect(lowerTick.amountIn).to.be.equal(BN_ZERO);
    expect(lowerTick.amountOut).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowthLast).to.be.equal(BN_ZERO);
    expect(lowerTick.liquidity).to.be.equal(liquidityAmount);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(lowerTick.amountInGrowth).to.be.equal(BN_ZERO);

    expect(upperTick.previousTick).to.be.equal(lower);
    expect(upperTick.nextTick).to.be.equal(upperOld);
    expect(upperTick.amountIn).to.be.equal(BN_ZERO);
    expect(upperTick.amountOut).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowthLast).to.be.equal(BN_ZERO);
    expect(upperTick.liquidity).to.be.equal(liquidityAmount);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
    expect(upperTick.amountInGrowth).to.be.equal(BN_ZERO);
  });

  // it('Should mint new LP position and then burn', async function () {
  //   const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
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

  // it('Should mint new LP position swap and then claim', async function () {
  //   const lowerOld = hre.ethers.utils.parseUnits("-887272", 0);
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