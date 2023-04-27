import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { gBefore } from '../../utils/hooks.test'

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
        let minPrice = BigNumber.from('4297706460')
        await expect(
            hre.props.coverPool.swap(
                hre.props.admin.address,
                true,
                BigNumber.from('0'),
                minPrice.sub(1)
            )
        ).to.be.revertedWith('PriceOutOfBounds()')
    })

    it('validatePrice - Should revert at or above max sqrt price', async function () {
        let maxPrice = BigNumber.from('1460570142285104104286607650833256105367815198570')
        await expect(
            hre.props.coverPool.swap(
                hre.props.admin.address,
                true,
                BigNumber.from('0'),
                maxPrice.add(1)
            )
        ).to.be.revertedWith('PriceOutOfBounds()')
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
