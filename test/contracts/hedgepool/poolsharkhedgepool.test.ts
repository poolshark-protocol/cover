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
import { validateMint } from '../../utils/contracts/hedgepool/hedgepool';

alice: SignerWithAddress;
describe('PoolsharkHedgePool Basic Tests', function () {

  let token0Amount: BigNumber;
  let token1Amount: BigNumber;
  let token0Decimals: number;
  let token1Decimals: number;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  before(async function () {
    await gBefore();

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
    console.log(await hre.props.hedgePool.positions(
      hre.props.alice.address,
      lower,
      upper
    ));
    // validateMint(

    // )
  });

  // mint at different price ranges
  // mint then burn at different price ranges
  // mint swap then burn
  // collect
})