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

  //TODO: mint position and burn as if there were 100

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

  it('Should set factory', async function () {
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

    await hre.props.coverPoolManager.connect(hre.props.admin).setFactory(hre.props.bob.address)

    expect(await
      hre.props.coverPoolManager
        .factory()
    ).to.be.equal(hre.props.bob.address)

    await hre.props.coverPoolManager.connect(hre.props.admin).setFactory(hre.props.coverPoolFactory.address)

    expect(await
      hre.props.coverPoolManager
        .factory()
    ).to.be.equal(hre.props.coverPoolFactory.address)
  })

  it('Should enable volatility tier', async function () {
    // check initial protocol fees
    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.bob)
        .enableVolatilityTier("100", "20", "20", "20", ethers.utils.parseUnits("1", 18), "1")
    ).to.be.revertedWith('OwnerOnly()')

    await expect(
      hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier("500", "40", "40", "40", ethers.utils.parseUnits("1", 18), "5")
    ).to.be.revertedWith('VolatilityTierAlreadyEnabled()')

    // should revert when non-admin calls
    let volatilityTierConfig = await
      hre.props.coverPoolManager
        .volatilityTiers("500", "40", "40");
    expect(volatilityTierConfig[0]).to.be.equal(40)
    expect(volatilityTierConfig[1]).to.be.equal(5)
    expect(volatilityTierConfig[2]).to.be.equal(ethers.utils.parseUnits("1", 18))

    expect((await
        hre.props.coverPoolManager
          .volatilityTiers("500", "30", "30"))[0]
      ).to.be.equal(0)

    await hre.props.coverPoolManager
        .connect(hre.props.admin)
        .enableVolatilityTier("500", "30", "30", "30", ethers.utils.parseUnits("1", 18), "5")

    volatilityTierConfig = await
        hre.props.coverPoolManager
        .volatilityTiers("500", "30", "30");
    expect(volatilityTierConfig[0]).to.be.equal(30)
    expect(volatilityTierConfig[1]).to.be.equal(5)
    expect(volatilityTierConfig[2]).to.be.equal(ethers.utils.parseUnits("1", 18))
  })
})
