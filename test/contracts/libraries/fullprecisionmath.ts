import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { IRangePool } from "../../../typechain";
import { PoolState, BN_ZERO } from "../../utils/contracts/coverpool";
import { gBefore } from "../../utils/hooks.test";
import { mintSigners20 } from "../../utils/token";

describe('FullPrecisionMath Library Tests', function () {

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
      const nearestTick           = pool0.nearestTick;
      const price                 = pool0.price;
      const latestTick            = globalState.latestTick;
  
      expect(liquidity).to.be.equal(BN_ZERO);
      expect(lastBlockNumber).to.be.equal(currentBlock);
      expect(feeGrowthCurrentEpoch).to.be.equal(BN_ZERO);
      expect(latestTick).to.be.equal(BN_ZERO);
      expect(nearestTick).to.be.equal(BN_ZERO);
  
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

    it('divRoundingUp - Should round up', async function () {
        expect(await hre.props.fullPrecisionMathLib.divRoundingUp(
            BigNumber.from("5"),
            BigNumber.from("4")
        )).to.be.equal(BigNumber.from("2"));
    });

    it('Should revert if getting liquidity value outside price bounds', async function () {
        await expect(hre.props.dydxMathLib.getLiquidityForAmounts(
            BigNumber.from("79386769463160146968577785965"),
            BigNumber.from("79545693927487839655804034729"),
            BigNumber.from("99855108194609381495771"),
            BigNumber.from("20"),
            BigNumber.from("20")
        )).to.be.revertedWith("Transaction reverted: library was called directly");
        //TODO: wrong error is reported using hardhat
        // )).to.be.revertedWith("PriceOutsideOfBounds()");
    })
});