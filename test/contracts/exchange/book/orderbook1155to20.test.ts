/* global describe it before ethers */
const hardhat = require('hardhat');
const { expect } = require("chai");
import { gBefore } from '../../../utils/hooks.test';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { hrtime } from "process";
import { BigNumber } from 'ethers';
import { gasUsed } from '../../../utils/blocks';
import { TEXT_COLOR } from '../../../utils/colors';
import { mintSigners1155, mintSigners20 } from '../../../utils/token';
import { validateLimitOrder1155To20 } from '../../../utils/contracts/exchange/book/orderbook1155to20';

alice: SignerWithAddress;
describe('OrderBook1155To20 Basic Tests', function () {

  let token1155Amount: BigNumber;
  let token20Amount: BigNumber;
  let token1155Decimals: number;
  let token20Decimals: number;
  let token1155Id: BigNumber;

  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let carol: SignerWithAddress;

  before(async function () {
  });

  this.beforeEach(async function () {
    await gBefore();
    token1155Id = BigNumber.from("0");
    token1155Decimals = 0;
    token20Decimals = await hre.props.token20.decimals();
    token1155Amount = ethers.utils.parseUnits("100", token1155Decimals);
    token20Amount = ethers.utils.parseUnits("100", token20Decimals);
    alice = hre.props.alice;
    bob   = hre.props.bob;
    carol = hre.props.carol;

    await mintSigners1155(
      hre.props.token1155,
      token1155Id,
      token1155Amount.mul(10),
      [hre.props.alice, hre.props.bob]
    )

    await mintSigners20(
      hre.props.token20,
      token20Amount.mul(10),
      [hre.props.alice, hre.props.bob]
    )
  });

  it('Should open new book and create a maker order', async function () {

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      true,
      false
    );

    console.log("%sFirst make in a new book: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  });

  it('Should open new book and get an empty taker order', async function (){
    
    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFirst take in an empty book: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  });

  it('Should create a new page and make twice on the same page', async function () {

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token20",
      "token1155",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      true,
      false
    );

    console.log("%sSecond make on the same page: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create 2 new pages on opposite trading directions with makerOnly', async function (){
    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token1155",
      "token20",
      token20Amount,
      token1155Amount,
      BigNumber.from("0"),
      true,
      false
    );
  });

  it('Should create 1 new page and partially take twice', async function () {

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.div(2),
      token1155Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token1155",
      "token20",
      token1155Amount.div(2),
      token20Amount.div(2),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFirst take on a new book with page clear: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.div(2),
      token1155Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token1155",
      "token20",
      token1155Amount.div(2),
      token20Amount.div(2),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sSecond take on a new book with page clear: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  });

  it('Should create 1 new page then take the entire page', async function () {

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.div(2),
      token1155Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.div(2),
      token1155Amount.div(2),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token1155",
      "token20",
      token1155Amount,
      token20Amount,
      BigNumber.from("0"),
      false,
      true
    );
    
    console.log("%sFulfillment of an entire single page: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create 2 new pages and fill both pages entirely', async function () {
    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.mul(20).div(100),
      token1155Amount.mul(25).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token20",
      "token1155",
      token20Amount.mul(25).div(100),
      token1155Amount.mul(20).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.bob,
      "token1155",
      "token20",
      token1155Amount.mul(90).div(100),
      token20Amount.mul(45).div(100),
      BigNumber.from("0"),
      false,
      true
    );

    console.log("%sFulfillment of two entire pages: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);

  })

  it('Should create an order and then successfully cancel it', async function () {
    await validateLimitOrder1155To20(
      "orderBook1155To20",
      hre.props.alice,
      "token20",
      "token1155",
      token20Amount.mul(20).div(100),
      token1155Amount.mul(25).div(100),
      BigNumber.from("0"),
      true,
      false
    );

    let txn = await hre.props.orderBook1155To20.connect(bob).cancelOrder(
      "0xea4ce585284e05eaad5d9b3458830c4e25c0c2c9ee2c8064673b304f154e575d",
      token20Amount.mul(20).div(100),
      token20Amount.mul(20).div(100)
    );
    await txn.wait();
    console.log("%sCancel of an order: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  it('Should create an order and then successfully cancel it and then process with a take', async function () {
    let txn = await hre.props.orderBook1155To20.connect(alice).limitOrder(
      hre.props.token20.address,
      token1155Id,
      token20Amount.mul(20).div(100),
      token1155Amount.mul(25).div(100),
      0,
      true,
      false
    );
    await txn.wait();
    // TODO: should revert since bob doesn't have an order
    txn = await hre.props.orderBook1155To20.connect(bob).cancelOrder(
      "0xea4ce585284e05eaad5d9b3458830c4e25c0c2c9ee2c8064673b304f154e575d",
      token20Amount.mul(20).div(100),
      token20Amount.mul(20).div(100)
    );
    await txn.wait();
    console.log("%sCancel of an order: %s%i %sgas%s", TEXT_COLOR.CYAN.value, TEXT_COLOR.PURPLE.value, await gasUsed(), TEXT_COLOR.CYAN.value, TEXT_COLOR.RESET.value);
  })

  //TODO: handle non-clean multiple of 1155 price
})