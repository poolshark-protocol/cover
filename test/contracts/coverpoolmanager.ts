/* global describe it before ethers */
const hardhat = require('hardhat')
const { expect } = require('chai')
import { gBefore } from '../utils/hooks.test'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber } from 'ethers'
import { BN_ZERO } from '../utils/contracts/coverpool'

alice: SignerWithAddress
describe('CoverPoolManager Tests', function () {
  let token0Amount: BigNumber
  let token1Amount: BigNumber
  let token0Decimals: number
  let token1Decimals: number
  let currentPrice: BigNumber

  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let carol: SignerWithAddress

  const liquidityAmount = BigNumber.from('99855108194609381495771')
  const minTickIdx = BigNumber.from('-887272')
  const maxTickIdx = BigNumber.from('887272')
  const uniV3String = ethers.utils.formatBytes32String('UNI-V3')
  const psharkString = ethers.utils.formatBytes32String('PSHARK-RANGE')

  before(async function () {
    await gBefore()
  })

  this.beforeEach(async function () {})

  it('Should be able to change owner', async function () {
    // check pool contract owner
    expect(await
        hre.props.coverPoolFactory
          .owner()
      ).to.be.equal(hre.props.coverPoolManager.address)

    // check admin contract owner
    expect(await
      hre.props.coverPoolManager
        .owner()
    ).to.be.equal(hre.props.admin.address)

    // expect revert if non-owner calls admin function
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.bob)
          .transferOwner(hre.props.bob.address)
    ).to.be.revertedWith('OwnerOnly()')

    // transfer ownership to bob
    await hre.props.coverPoolManager.connect(hre.props.admin).transferOwner(hre.props.bob.address)
    
    // expect bob to be the new admin
    expect(await
        hre.props.coverPoolManager
          .owner()
      ).to.be.equal(hre.props.bob.address)
    
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.admin)
          .transferOwner(hre.props.bob.address)
    ).to.be.revertedWith('OwnerOnly()')

    // transfer ownership back to previous admin
    await hre.props.coverPoolManager.connect(hre.props.bob).transferOwner(hre.props.admin.address)
    
    // check admin is owner again
    expect(await
        hre.props.coverPoolManager
        .owner()
    ).to.be.equal(hre.props.admin.address)
  })

  it('Should be able to change feeTo', async function () {
    // check admin contract feeTo
    expect(await
      hre.props.coverPoolManager
        .feeTo()
    ).to.be.equal(hre.props.admin.address)

    // owner should not be able to claim fees
    await hre.props.coverPoolManager.connect(hre.props.admin).transferOwner(hre.props.bob.address)

    // expect revert if non-owner calls admin function
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.bob)
          .transferFeeTo(hre.props.bob.address)
    ).to.be.revertedWith('FeeToOnly()')

    await hre.props.coverPoolManager.connect(hre.props.bob).transferOwner(hre.props.admin.address)

    // transfer ownership to bob
    await hre.props.coverPoolManager.connect(hre.props.admin).transferFeeTo(hre.props.bob.address)
    
    // expect bob to be the new admin
    expect(await
        hre.props.coverPoolManager
          .feeTo()
      ).to.be.equal(hre.props.bob.address)
    
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.admin)
          .transferFeeTo(hre.props.bob.address)
    ).to.be.revertedWith('FeeToOnly()')

    // transfer ownership back to previous admin
    await hre.props.coverPoolManager.connect(hre.props.bob).transferFeeTo(hre.props.admin.address)
    
    // check admin is owner again
    expect(await
        hre.props.coverPoolManager
        .feeTo()
    ).to.be.equal(hre.props.admin.address)
  })

  it('Should set protocol fees on cover pools', async function () {
    // check initial protocol fees
    expect(await
      hre.props.coverPoolManager
        .protocolFee()
    ).to.be.equal(BN_ZERO)

    // should revert when non-admin calls
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.bob)
          .setProtocolFee("500")
    ).to.be.revertedWith('OwnerOnly()')

    // set protocol fees on top pools
    await hre.props.coverPoolManager.connect(hre.props.admin).setProtocolFee("500")
    // check new fee set
    expect(await
        hre.props.coverPoolManager
          .protocolFee()
      ).to.be.equal(500)
    
    await hre.props.coverPoolManager.connect(hre.props.admin).transferOwner(hre.props.bob.address)

    // remove protocol fees on top pools
    await hre.props.coverPoolManager.connect(hre.props.bob).setProtocolFee("0")

    // check new fee set
    expect(await
        hre.props.coverPoolManager
            .protocolFee()
        ).to.be.equal(0)

    // should revert when non-admin calls
    await expect(
        hre.props.coverPoolManager
            .connect(hre.props.admin)
            .setProtocolFee("500")
    ).to.be.revertedWith('OwnerOnly()')
  
    await hre.props.coverPoolManager.connect(hre.props.bob).transferOwner(hre.props.admin.address)
  })

  it('Should collect fees from cover pools', async function () {
    // check initial protocol fees
    await
      hre.props.coverPoolManager
        .collectProtocolFees([hre.props.coverPool.address])
    
    // without protocol fees balances should not change
    //TODO: validate erc-20 balance changes

    // anyone can send fees to the feeTo address
    hre.props.coverPoolManager
          .connect(hre.props.bob)
          .collectProtocolFees([hre.props.coverPool.address])
  })

  it('Should not set factory', async function () {
    // check initial protocol fees
    expect(await
      hre.props.coverPoolManager
        .factory()
    ).to.be.equal(hre.props.coverPoolFactory.address)

    // should revert when non-admin calls
    await expect(
        hre.props.coverPoolManager
          .connect(hre.props.bob)
          .setFactory(hre.props.bob.address)
    ).to.be.revertedWith('OwnerOnly()')

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .setFactory(hre.props.bob.address)
  ).to.be.revertedWith('FactoryAlreadySet()')

    expect(await
      hre.props.coverPoolManager
        .factory()
    ).to.be.equal(hre.props.coverPoolFactory.address)
  })

  it('Should not create volatility tier for a fee tier not supported', async function () {
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "1000", "40", "40", ethers.utils.parseUnits("1", 18), "40", "1000", "0", "0", "4", true)
    ).to.be.revertedWith('FeeTierNotSupported()')
  })

  it('Should not create volatility tier w/ tick spread equal to tick spacing', async function () {
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "10", "20", ethers.utils.parseUnits("1", 18), "20", "1000", "0", "0", "1",  true)
    ).to.be.revertedWith('TickSpreadNotAtLeastDoubleTickSpread()')
  })

  it('Should not create pool without clean multiple of tick spacing', async function () {
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "25", "20", ethers.utils.parseUnits("1", 18), "20", "1000", "0", "0", "1", true)
    ).to.be.revertedWith('TickSpreadNotMultipleOfTickSpacing()')
  })

  it('Should enable new twap source', async function () {
    await hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableTwapSource(psharkString, hre.props.uniswapV3Source.address)
    
    expect(await hre.props.coverPoolManager
      .twapSources(psharkString))
      .to.be.equal(hre.props.uniswapV3Source.address)
  })


  it('Should not enable twap source with OwnerOnly()', async function () {
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.bob)
        .enableTwapSource(psharkString, hre.props.uniswapV3Source.address)
    ).to.be.revertedWith('OwnerOnly()')
  })

  it('Should not enable twap source with invalid string', async function () {
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableTwapSource(ethers.utils.formatBytes32String(''), hre.props.uniswapV3Source.address)
    ).to.be.revertedWith('TwapSourceNameInvalid()')
  })

  it('Should enable volatility tier', async function () {
    // should revert when non-admin calls
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.bob)
        .enableVolatilityTier(uniV3String, "100", "20", "20", ethers.utils.parseUnits("1", 18), "20", "1000", "0", "0", "1", true)
    ).to.be.revertedWith('OwnerOnly()')

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "20", "5", ethers.utils.parseUnits("1", 18), "10", "1000", "0", "0", "5", true)
    ).to.be.revertedWith('VolatilityTierAlreadyEnabled()')

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "40", "10", ethers.utils.parseUnits("1", 18), "40", "1000", "0", "0", "4", true)
    ).to.be.revertedWith('VolatilityTierAlreadyEnabled()')

    let volatilityTierConfig = await
      hre.props.coverPoolManager
        .volatilityTiers("500", "40", "10");
    expect(volatilityTierConfig[0]).to.be.equal(ethers.utils.parseUnits("1", 18))
    expect(volatilityTierConfig[1]).to.be.equal(10)
    expect(volatilityTierConfig[2]).to.be.equal(1000)
    expect(volatilityTierConfig[3]).to.be.equal(500)
    expect(volatilityTierConfig[4]).to.be.equal(5000)
    expect(volatilityTierConfig[5]).to.be.equal(5)
    expect(volatilityTierConfig[6]).to.be.equal(false)

    expect((await
        hre.props.coverPoolManager
          .volatilityTiers("500", "30", "30"))[0]
      ).to.be.equal(0)

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "30", "4", ethers.utils.parseUnits("1", 18), "4", "1000", "0", "0", "4", true)
    ).to.be.revertedWith('VoltatilityTierTwapTooShort()')

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "30", "0", ethers.utils.parseUnits("1", 18), "30", "1000", "0", "0", "4", true)
    ).to.be.revertedWith('VoltatilityTierTwapTooShort()')

    await hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier(uniV3String, "500", "30", "30", ethers.utils.parseUnits("1", 18), "30", "1000", "50", "500", "5", true)

    volatilityTierConfig = await
        hre.props.coverPoolManager
        .volatilityTiers("500", "30", "30");
        expect(volatilityTierConfig[0]).to.be.equal(ethers.utils.parseUnits("1", 18))
        expect(volatilityTierConfig[1]).to.be.equal(30)
        expect(volatilityTierConfig[2]).to.be.equal(1000)
        expect(volatilityTierConfig[3]).to.be.equal(50)
        expect(volatilityTierConfig[4]).to.be.equal(500)
        expect(volatilityTierConfig[5]).to.be.equal(5)
        expect(volatilityTierConfig[6]).to.be.equal(true)
  })
})
