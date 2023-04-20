import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { IRangePool } from '../../../typechain'
import { PoolState, BN_ZERO } from '../../utils/contracts/coverpool'
import { gBefore } from '../../utils/hooks.test'
import { mintSigners20 } from '../../utils/token'

describe('TickMath Library Tests', function () {
    let token0Amount: BigNumber
    let token1Amount: BigNumber
    let token0Decimals: number
    let token1Decimals: number
    let currentPrice: BigNumber

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress

    before(async function () {
        await gBefore()
    })

    this.beforeEach(async function () {})

    it('validatePrice - Should revert below min sqrt price', async function () {
        await expect(
            hre.props.tickMathLib.validatePrice(BigNumber.from('4295128738'))
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })

    it('validatePrice - Should revert at max sqrt price', async function () {
        await expect(
            hre.props.tickMathLib.validatePrice(
                BigNumber.from('1461446703485210103287273052203988822378723970342')
            )
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })

    it('getSqrtRatioAtTick - Should get tick near min sqrt price', async function () {
        expect(
            await hre.props.tickMathLib.getSqrtRatioAtTick(BigNumber.from('-887272'))
        ).to.be.equal(BigNumber.from('4295128739'))
    })

    it('getTickAtSqrtRatio - Should get tick at min sqrt price', async function () {
        expect(
            await hre.props.tickMathLib.getTickAtSqrtRatio(BigNumber.from('4295128739'))
        ).to.be.equal(BigNumber.from('-887272'))
    })

    it('getTickAtSqrtRatio - Should get tick at sqrt price', async function () {
        expect(
            await hre.props.tickMathLib.getTickAtSqrtRatio(BigNumber.from('83095200000000000000000000000'))
        ).to.be.equal(BigNumber.from('953'))
    })

    it('getTickAtSqrtRatio - Should get tick near max sqrt price', async function () {
        expect(
            await hre.props.tickMathLib.getTickAtSqrtRatio(
                BigNumber.from('1461446703485210103287273052203988822378723970341')
            )
        ).to.be.equal(BigNumber.from('887271'))
    })

    it('getTickAtSqrtRatio - Should revert at max sqrt price', async function () {
        await expect(
            hre.props.tickMathLib.getTickAtSqrtRatio(
                BigNumber.from('1461446703485210103287273052203988822378723970342')
            )
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })

    it('getTickAtSqrtRatio - Should revert when sqrt price is below bounds', async function () {
        await expect(
            hre.props.tickMathLib.getTickAtSqrtRatio(BigNumber.from('4295128738'))
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })

    it('getTickAtSqrtRatio - Should revert when sqrt price is above bounds', async function () {
        await expect(
            hre.props.tickMathLib.getTickAtSqrtRatio(
                BigNumber.from('1461446703485210103287273052203988822378723970343')
            )
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })
})
