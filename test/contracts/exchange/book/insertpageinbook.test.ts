const hardhat = require('hardhat');
const { expect } = require("chai");
import { OrderBook20, OrderBookFactory20__factory, OrderBookRouter20__factory, Token20__factory } from "../../../../typechain";
import { BigNumber, BigNumberish, ContractTransaction } from "ethers";
import { gasUsed } from "../../../utils/blocks";
import { TEXT_COLOR } from "../../../utils/colors";
import { ethers } from "hardhat";
import { gBefore } from "../../../utils/hooks.test";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { mintSigners20 } from "../../../utils/token";
import { validateLimitOrder20 } from "../../../utils/contracts/exchange/book/orderbook20";
describe('Insert Page Tests', function () {

  let token0Amount: BigNumber;
  let token1Amount: BigNumber;
  let token0Decimals: number;
  let token1Decimals: number;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  before(async function () {

  });

  this.beforeEach(async function () {
    await gBefore();
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

  it('Should create a new page and insert in the middle', async function () {

    
    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount,
      token0Amount,
      BigNumber.from("0"),
      true,
      false
    );
    console.log("%sFirst make in a new book: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token1",
      "token0",
      token1Amount.div(2),
      token0Amount,
      BigNumber.from("0"),
      true,
      false
    );
    console.log("%sSecond make at higher price: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token1",
      "token0",
      token1Amount,
      token0Amount.mul(3).div(4),
      BigNumber.from("0"),
      true,
      false
    );
    console.log("%sThird make at middle price: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

    const quote = await hre.props.orderBook20.quoteExactAmountOut(
        hre.props.token0.address,
        token0Amount.mul(6),
        token1Amount.mul(3)
      );

      let fromAmountIn = ethers.utils.parseUnits("275", token0Decimals);
      let destAmountOut = ethers.utils.parseUnits("250", token0Decimals);

      expect(quote[0]).to.be.equal(fromAmountIn);
      expect(quote[1]).to.be.equal(destAmountOut);
    });
});