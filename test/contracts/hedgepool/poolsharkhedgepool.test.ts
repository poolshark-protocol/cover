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
import { validateMint, Position, Q64x96, BN_ZERO, validateSwap, validateBurn } from '../../utils/contracts/hedgepool/hedgepool';

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

  before(async function () {
    await gBefore();
    let currentBlock = await ethers.provider.getBlockNumber();
    //TODO: maybe just have one view function that grabs all these
    //TODO: map it to an interface
    const liquidity           = await hre.props.hedgePool.liquidity();
    const secondsGrowthGlobal = await hre.props.hedgePool.secondsGrowthGlobal();
    const lastBlockNumber     = await hre.props.hedgePool.lastBlockNumber();
    const feeGrowthGlobalIn     = await hre.props.hedgePool.feeGrowthGlobalIn();
    const latestTick          = await hre.props.hedgePool.latestTick();
    const nearestTick         = await hre.props.hedgePool.nearestTick();

    expect(liquidity).to.be.equal(BN_ZERO);
    expect(secondsGrowthGlobal).to.be.equal(BN_ZERO);
    expect(lastBlockNumber).to.be.equal(currentBlock);
    expect(feeGrowthGlobalIn).to.be.equal(BN_ZERO);
    expect(latestTick).to.be.equal(BN_ZERO);
    expect(nearestTick).to.be.equal(BN_ZERO);

    // console.log("sqrt price:", await (await hre.props.hedgePool.sqrtPrice()).toString());
    currentPrice = await hre.props.hedgePool.sqrtPrice();
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
    const lowerTick = await hre.props.hedgePool.ticks(
      lower
    );
    const upperTick = await hre.props.hedgePool.ticks(
      upper
    );

    expect(lowerTick.previousTick).to.be.equal(lowerOld);
    expect(lowerTick.nextTick).to.be.equal(upper);
    expect(lowerTick.liquidity).to.be.equal(liquidityAmount);

    expect(upperTick.previousTick).to.be.equal(lower);
    expect(upperTick.nextTick).to.be.equal(upperOld);
    expect(upperTick.liquidity).to.be.equal(liquidityAmount);
  });

  it('Should swap with zero output', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("0", 0);
    const lower    = hre.ethers.utils.parseUnits("20", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("30", 0);
    const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());

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

  //TODO: allow partial position placement and refund liquidity not being used
  it('Should move TWAP before mint and do a successful swap', async function () {
    const lowerOld = hre.ethers.utils.parseUnits("50", 0);
    const lower    = hre.ethers.utils.parseUnits("60", 0);
    const upperOld = hre.ethers.utils.parseUnits("887272", 0);
    const upper    = hre.ethers.utils.parseUnits("90", 0);
    const burnAmount = hre.ethers.utils.parseUnits("66420461859385355519898", 0);

    // move TWAP to tick 50
    let txn = await hre.props.concentratedPoolMock.setTickCumulatives(
      6000,
      3000
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

  // it('Should fail on second claim', async function () {
  //   const lowerOld = hre.ethers.utils.parseUnits("0", 0);
  //   const lower    = hre.ethers.utils.parseUnits("20", 0);
  //   const upperOld = hre.ethers.utils.parseUnits("887272", 0);
  //   const upper    = hre.ethers.utils.parseUnits("30", 0);
  //   const amount   = hre.ethers.utils.parseUnits("100", await hre.props.token0.decimals());

  //   await expect(hre.props.hedgePool.burn(
  //     lower,
  //     upper,
  //     upper,
  //     liquidityAmount
  //   )).to.be.revertedWith("NotEnoughPositionLiquidity()");
  // });

  // TODO: partial mint
  // TODO: claim liquidity filled
  // TODO: empty swap at price limit higher than current price
  // TODO: move TWAP again and fill remaining
  // TODO: claim final amount and burn LP position
  // TODO: mint LP position with priceLower < currentPrice
  // TODO: P1 larger range; P2 smaller range; execute swap and validate amount returned by claiming
  // TODO: smaller range claims first; larger range claims first
  // TODO: move TWAP down and allow for new positions to be entered

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