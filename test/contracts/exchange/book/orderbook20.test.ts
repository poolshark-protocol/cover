/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../../../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { hrtime } from "process";
import { BigNumber } from 'ethers';
import { gasUsed } from '../../../utils/blocks';
import { TEXT_COLOR } from '../../../utils/colors';
import { mintSigners20 } from '../../../utils/token';
import { validateLimitOrder20 } from '../../../utils/contracts/exchange/book/orderbook20';

alice: SignerWithAddress;
describe('OrderBook20 Basic Tests', function () {

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

  it('Should open new book and create a maker order', async function () {

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.mul(80).div(100),
      token0Amount,
      token0Amount,
      true,
      false
    );

    console.log("%sFirst make in a new book: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount,
      token0Amount.mul(5),
      ethers.utils.parseUnits("5", 18),
      true,
      false
    );
  });

  it('Should open new book and get an empty taker order', async function (){
    
    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount,
      token0Amount,
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFirst take in an empty book: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  });

  it('Should create a new page and make twice on the same page', async function () {

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

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token1",
      "token0",
      token1Amount,
      token0Amount,
      BigNumber.from("0"),
      true,
      false
    );

    console.log("%sSecond make on the same page: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

    // should quote 2x amount
    const quote: [BigNumber, BigNumber] = await hre.props.orderBook20.quoteExactAmountOut(
      hre.props.token0.address,
      token0Amount.mul(2),
      token1Amount.mul(2)
    );

    expect(quote[0]).to.be.equal(token0Amount.mul(2));
    expect(quote[1]).to.be.equal(token1Amount.mul(2));
  })

  it('Should create 2 new pages on opposite trading directions with makerOnly', async function (){
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

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token0",
      "token1",
      token1Amount,
      token0Amount,
      BigNumber.from("0"),
      true,
      false
    );
  });

  it('Should create 1 new page and partially take twice', async function () {

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.div(2),
      token0Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token0",
      "token1",
      token0Amount.div(2),
      token1Amount.div(2),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFirst take on a new book with page clear: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.div(2),
      token0Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token0",
      "token1",
      token0Amount.div(2),
      token1Amount.div(2),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sSecond take on a new book with page clear: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  });

  it('Should create 1 new page then take the entire page', async function () {

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.div(2),
      token0Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.div(2),
      token0Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token0",
      "token1",
      token0Amount,
      token1Amount,
      BigNumber.from("0"),
      false,
      true
    );
    
    console.log("%sFulfillment of an entire single page: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create 2 new pages and fill both pages entirely', async function () {
    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.mul(20).div(100),
      token0Amount.mul(25).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token1",
      "token0",
      token1Amount.mul(25).div(100),
      token0Amount.mul(20).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token0",
      "token1",
      token0Amount.mul(90).div(100),
      token1Amount.mul(45).div(100),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFulfillment of two entire pages: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

  })

  it('Should create an order and then successfully cancel it', async function () {
    await validateLimitOrder20(
      "orderBook20",
      hre.props.alice,
      "token1",
      "token0",
      token1Amount.mul(20).div(100),
      token0Amount.mul(25).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    let txn = await hre.props.orderBook20.connect(bob).cancelOrder(
      "0xea4ce585284e05eaad5d9b3458830c4e25c0c2c9ee2c8064673b304f154e575d",
      token1Amount.mul(20).div(100),
      token1Amount.mul(20).div(100)
    );
    await txn.wait();
    console.log("%sCancel of an order: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create an order and then successfully cancel it and then process with a take', async function () {
    let txn = await hre.props.orderBook20.connect(alice).limitOrder(
      hre.props.token1.address,
      token1Amount.mul(20).div(100),
      token0Amount.mul(25).div(100),
      0,
      true,
      false
    );
    await txn.wait();
    // TODO: should revert since bob doesn't have an order
    txn = await hre.props.orderBook20.connect(bob).cancelOrder(
      "0xea4ce585284e05eaad5d9b3458830c4e25c0c2c9ee2c8064673b304f154e575d",
      token1Amount.mul(20).div(100),
      token1Amount.mul(20).div(100)
    );
    await txn.wait();
    console.log("%sCancel of an order: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create a maker order, process a taker order, and then allow the maker to claim', async function () {
    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token1",
      "token0",
      token1Amount.mul(25).div(100),
      token0Amount.mul(20).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder20(
      "orderBook20",
      hre.props.bob,
      "token0",
      "token1",
      token0Amount.mul(90).div(100),
      token1Amount.mul(45).div(100),
      BigNumber.from("0"),
      false,
      true
    );
    // await txn.wait();
    // // TODO: should revert since bob doesn't have an order
    let txn = await hre.props.orderBook20.connect(bob).claimOrders(
      ["800000000000000000"],
      [token1Amount.mul(25).div(100)],
      [hre.props.token0.address],
      [token0Amount.mul(20).div(100)]
    );
    await txn.wait();
    // await txn.wait();
    console.log("%sClaim of an order: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })
})