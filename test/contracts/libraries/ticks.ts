import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { IRangePool } from "../../../typechain";
import { PoolState, BN_ZERO } from "../../utils/contracts/coverpool";
import { gBefore } from "../../utils/hooks.test";
import { mintSigners20 } from "../../utils/token";

describe('Ticks Library Tests', function () {

    let token0Amount: BigNumber;
    let token1Amount: BigNumber;
    let token0Decimals: number;
    let token1Decimals: number;
    let currentPrice: BigNumber;
  
    let alice: SignerWithAddress;
    let bob: SignerWithAddress;
    let carol: SignerWithAddress;
  
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
      const price                 = pool0.price;
      const latestTick            = globalState.latestTick;
  
      expect(liquidity).to.be.equal(BN_ZERO);
      expect(lastBlockNumber).to.be.equal(currentBlock);
      expect(feeGrowthCurrentEpoch).to.be.equal(BN_ZERO);
      expect(latestTick).to.be.equal(BN_ZERO);
  
      // console.log("sqrt price:", await (await hre.props.coverPool.sqrtPrice()).toString());
      currentPrice = BigNumber.from("2").pow(96);
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

    // it('accumulate() - pool0 - Should not rollover if filled', async function () {
    //     const result = await hre.props.ticksLib.accumulate(
    //         {previousTick: 0, nextTick: 20, accumEpochLast: 1},
    //         {}
    //     )
    //     expect(result[0]).to.be.equal(BigNumber.from("0"));
    //     expect(result[1]).to.be.equal(BigNumber.from("0"));
    // });

    it('rollover() - pool0 - Should not rollover if filled', async function () {
        const result = await hre.props.ticksLib.rollover(
            BigNumber.from("20"),
            BigNumber.from("0"),
            BigNumber.from("79228162514264337593543950336"),
            BigNumber.from("99955008249587388643769"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            false
        )
        expect(result[0]).to.be.equal(BigNumber.from("0"));
        expect(result[1]).to.be.equal(BigNumber.from("0"));
    });

    it('rollover() - pool1 - Should not rollover if filled', async function () {
        const result = await hre.props.ticksLib.rollover(
            BigNumber.from("0"),
            BigNumber.from("20"),
            BigNumber.from("79307426338960776842885539845"),
            BigNumber.from("99955008249587388643769"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            false
        )
        expect(result[0]).to.be.equal(BigNumber.from("0"));
        expect(result[1]).to.be.equal(BigNumber.from("0"));
    });

    it('rollover() - pool0 - Should rollover unfilled amounts', async function () {
        const result = await hre.props.ticksLib.rollover(
            BigNumber.from("20"),
            BigNumber.from("0"),
            BigNumber.from("79307426338960776842885539845"),
            BigNumber.from("99955008249587388643769"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            true
        )
        expect(result[0]).to.be.equal(BigNumber.from("-79263824696439249340797497"));
        expect(result[1]).to.be.equal(BigNumber.from("79184604449414017477223073"));
    });

    it('rollover() - pool1 - Should rollover unfilled amounts', async function () {
        const result = await hre.props.ticksLib.rollover(
            BigNumber.from("0"),
            BigNumber.from("20"),
            BigNumber.from("79228162514264337593543950336"),
            BigNumber.from("99955008249587388643769"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            false
        )
        expect(result[0]).to.be.equal(BigNumber.from("-79184604449414017477223073"));
        expect(result[1]).to.be.equal(BigNumber.from("79263824696439249340797497"));
    });

    it('rollover() - pool1 - Should return 0 if currentLiquidity is 0', async function () {
        const result = await hre.props.ticksLib.rollover(
            BigNumber.from("0"),
            BigNumber.from("20"),
            BigNumber.from("79228162514264337593543950336"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            BigNumber.from("0"),
            false
        )
        expect(result[0]).to.be.equal(BigNumber.from("0"));
        expect(result[1]).to.be.equal(BigNumber.from("0"));
    });
});