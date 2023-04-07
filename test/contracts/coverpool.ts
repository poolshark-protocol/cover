/* global describe it before ethers */
const hardhat = require('hardhat')
const { expect } = require('chai')
import { gBefore } from '../utils/hooks.test'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber } from 'ethers'
import { mintSigners20 } from '../utils/token'
import {
    validateMint,
    BN_ZERO,
    validateSwap,
    validateBurn,
    PoolState,
    validateSync,
    getLatestTick,
    getLiquidity,
    getPrice,
    getTick,
    getPositionLiquidity,
} from '../utils/contracts/coverpool'

// TODO: ✔ pool0 - Should handle partial mint (479ms)
// position before liquidity: BigNumber { _hex: '0x00', _isBigNumber: true }
//     1) pool0 - Should handle partial range cross w/ unfilled amount
/// ^this causes infinite tick loop

alice: SignerWithAddress
describe('CoverPool Tests', function () {
    let tokenAmount: BigNumber
    let token0Decimals: number
    let token1Decimals: number
    let minPrice: BigNumber
    let maxPrice: BigNumber

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress

    const liquidityAmount = BigNumber.from('99855108194609381495771')
    const minTickIdx = BigNumber.from('-887272')
    const maxTickIdx = BigNumber.from('887272')

    ////////// DEBUG FLAGS //////////
    const debugMode           = false
    const balanceCheck        = false
    const deltaMaxBeforeCheck = false
    const deltaMaxAfterCheck  = true
    const latestTickCheck     = false

    //every test should clear out all liquidity

    before(async function () {
        await gBefore()
        let currentBlock = await ethers.provider.getBlockNumber()
        //TODO: maybe just have one view function that grabs all these
        //TODO: map it to an interface
        const pool0: PoolState = await hre.props.coverPool.pool0()
        const liquidity = pool0.liquidity
        const globalState = await hre.props.coverPool.globalState()
        const genesisBlock = globalState.genesisBlock
        const amountInDelta = pool0.amountInDelta
        const price = pool0.price
        const latestTick = globalState.latestTick

        expect(liquidity).to.be.equal(BN_ZERO)
        expect(genesisBlock).to.be.equal(currentBlock)
        expect(amountInDelta).to.be.equal(BN_ZERO)
        expect(latestTick).to.be.equal(BN_ZERO)

        minPrice = BigNumber.from('4295128739')
        maxPrice = BigNumber.from('1461446703485210103287273052203988822378723970341')
        token0Decimals = await hre.props.token0.decimals()
        token1Decimals = await hre.props.token1.decimals()
        tokenAmount = ethers.utils.parseUnits('100', token0Decimals)
        tokenAmount = ethers.utils.parseUnits('100', token1Decimals)
        alice = hre.props.alice
        bob = hre.props.bob
        carol = hre.props.carol
    })

    this.beforeEach(async function () {
        await mintSigners20(hre.props.token0, tokenAmount.mul(10), [hre.props.alice, hre.props.bob])

        await mintSigners20(hre.props.token1, tokenAmount.mul(10), [hre.props.alice, hre.props.bob])

        await hre.props.rangePoolMock.setObservationCardinality('5')
    })

    it('pool0 - Should wait until enough observations', async function () {
        await hre.props.rangePoolMock.setObservationCardinality('4')
        // mint should revert
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '0',
            upper: '0',
            claim: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'WaitUntilEnoughObservations()',
            collectRevertMessage: 'WaitUntilEnoughObservations()'
        })

        // no-op swap
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: 'WaitUntilEnoughObservations()',
            syncRevertMessage: 'WaitUntilEnoughObservations()'
        })

        // burn should revert
        await validateBurn({
            signer: hre.props.alice,
            lower: '0',
            upper: '0',
            claim: '0',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WaitUntilEnoughObservations()',
        })
    })

    it('pool1 - Should wait until enough observations', async function () {
        await hre.props.rangePoolMock.setObservationCardinality('4')
        // mint should revert
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '0',
            upper: '0',
            claim: '0',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'WaitUntilEnoughObservations()',
            collectRevertMessage: 'WaitUntilEnoughObservations()',
        })

        // no-op swap
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount,
            priceLimit: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: 'WaitUntilEnoughObservations()',
            syncRevertMessage: 'WaitUntilEnoughObservations()'
        })

        // burn should revert
        await validateBurn({
            signer: hre.props.alice,
            lower: '0',
            upper: '0',
            claim: '0',
            liquidityAmount: liquidityAmount,
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WaitUntilEnoughObservations()',
        })
    })

    it('pool0 - Should mint/burn new LP position', async function () {
        // process two mints
        for (let i = 0; i < 2; i++) {
            await validateMint({
                signer: hre.props.alice,
                recipient: hre.props.alice.address,
                lower: '-40',
                claim: '-20',
                upper: '-20',
                amount: tokenAmount,
                zeroForOne: true,
                balanceInDecrease: tokenAmount,
                liquidityIncrease: liquidityAmount,
                upperTickCleared: false,
                lowerTickCleared: false,
                revertMessage: '',
            })
        }

        // process no-op swap
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        if (deltaMaxBeforeCheck) {
            console.log('final tick')
            console.log('deltainmax  before:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax before:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }

        // process two burns
        for (let i = 0; i < 2; i++) {
            await validateBurn({
                signer: hre.props.alice,
                lower: '-40',
                claim: '-20',
                upper: '-20',
                liquidityAmount: liquidityAmount,
                zeroForOne: true,
                balanceInIncrease: BN_ZERO,
                balanceOutIncrease: tokenAmount.sub(1),
                lowerTickCleared: false,
                upperTickCleared: false,
                revertMessage: '',
            })
        }
        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should mint, swap, and then claim entire range', async function () {
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('99680524411508040121'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount,
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('99680524411508040121'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            liquidityAmount: BigNumber.from('1'),
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })
        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should revert if tick not divisible by tickSpread', async function () {
        // move TWAP to tick 0
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-30',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidLowerTick()',
        })

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-10',
            upper: '-10',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidUpperTick()',
        })
    })

    it('pool0 - Should swap with zero output', async function () {
        // move TWAP to tick 0
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should handle partial mint', async function () {
        const liquidityAmount3 = BigNumber.from('49952516624167694475096')
        const tokenAmount3 = BigNumber.from('50024998748000306423')
        // move TWAP to tick 0
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount3,
            liquidityIncrease: liquidityAmount3,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
            expectedUpper: '-20',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '0',
            upper: '0',
            liquidityAmount: liquidityAmount3,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount3.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount3,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount3.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should move TWAP in range, partial fill, and burn 43', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10040069750091208712'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('89959930249908791288'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }

        await validateSync(0)
    })

    it('pool0 - Should handle partial range cross w/ unfilled amount', async function () {
        const liquidityAmount4 = BigNumber.from('49952516624167694475096')

        await validateSync(20)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10040071764942830081'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '0',
            upper: '0',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '0',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('89959928235057169918'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-20')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-20')).deltas.amountOutDeltaMax.toString())
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should move TWAP in range, partial fill, sync lower tick, and burn 54', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        hre.props.dydxMathLib

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79148977909814923576066331265'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10040069750091208712'),
            revertMessage: '',
        })

        await validateSync(-40)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999999'),
            balanceOutIncrease: BigNumber.from('89959930249908791288'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateSync(-60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999999'),
            balanceOutIncrease: BigNumber.from('89959930249908791288'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999999'),
            balanceOutIncrease: BigNumber.from('89959930249908791287'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateSync(-40)
        await validateSync(-20)

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it("pool0 - underflow when claiming for the second time :: GUARDIAN AUDITS", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('24951283310825598484485')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-80',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("24951283310825598484485");

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('24907659208740128447'),
            balanceOutIncrease: BigNumber.from('24987488133503998990'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-80',
            claim: '-20',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('24907659208740128447'),
            balanceOutIncrease: BigNumber.from('49987513124744754072'),
            lowerTickCleared: false,
            upperTickCleared: true,
            expectedUpper: '-40',
            revertMessage: '',
        });
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSync(-40);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSync(-60);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSync(-80);

        // Notice that the following burn reverts -- if the subtraction from the end tick in section2
        // is removed the double counting no longer occurs -- and the burn can succeed.

        // Notice that after implementing the suggested fix above, 
        // during the burn we log a percentInOnTick value that is greater than 100
        // This is due to section2 counting a larger price range then it ought to.
        // Currently, the section2 function will include tick -20 in it's calculations.
        // However tick -20 was already claimed by the user in the previous burn from section4.
        // The priceClaimLast ought to be updated to tick -40 in section1, but since the previous auction
        // was fully filled, it was not. The fix for this is to allow this case to enter the else if in
        // section1 so that the cache.position.claimPriceLast can be pushed to tick -40.
        await validateBurn({
            signer: hre.props.alice,
            lower: '-80',
            claim: '-80',
            upper: '-40',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('25024998741751246936'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        });

    });

    it("pool0 - outdated price does not perturb the pool accounting :: GUARDIAN AUDITS", async function () {
        const liquidityAmountBob = BigNumber.from('497780033507028255257726') 
        await validateSync(0);

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        // Bob also mints a much larger position further down the ticks
        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-100',
            claim: '-20',
            upper: '-80',
            amount: tokenAmount.mul(5),
            zeroForOne: true,
            balanceInDecrease: tokenAmount.mul(5),
            liquidityIncrease: liquidityAmountBob,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateSync(-20); // The outdated price that will be used during the swap

        await validateSync(-60, false);

        // Even though there was not nearly enough liquidity at the current tick (-60)
        // I was able to swap 200 of token 1 for token 0... and I stole from the funds in Bob's
        // position (liquidity that should not be available at this tick) to do so.

        /// @alphak3y - FIXED => there should be nothing to swap here
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        });
        await getLatestTick(latestTickCheck) // set to true to print 

        // This is because the PoolState memory pool variable is cached before
        // the syncLatest is performed. Therefore the cache.price used in the swap will be outdated.
        // If the Twap price moves ahead of this outdated price, the outdated price will now be
        // higher than the Twap price -- resulting in an underflow when we calculate maxDy.
        // Therefore maxDy is on the order of magnitude of the max uint256.
        // With maxDy exceedingly high any amount can be swapped in the current auction, severely perturbing
        // the pool's accounting.

        // *Note the maxDy value is being logged so you can see it is nearly the max uint256.
        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await getLatestTick(latestTickCheck)

        const balanceOutIncrease1 = BigNumber.from('100300435406274192565')

        await validateBurn({
            signer: hre.props.bob,
            lower: '-100',
            claim: '-80',
            upper: '-80',
            liquidityAmount: liquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: balanceOutIncrease1,
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.bob,
            lower: '-100',
            claim: '-80',
            upper: '-80',
            liquidityAmount: liquidityAmountBob.sub(liquidityAmount),
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.mul(5).sub(1).sub(balanceOutIncrease1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
    });

    it("pool0 - liquidityDelta added to stash tick for resuming position fill :: GUARDIAN AUDITS", async function () {
        await validateSync(20);

        const aliceLiquidity = BigNumber.from("33285024970969944913475")

        // Alice creates a position from 0 -> -20
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidity,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
            expectedUpper: '0',
        });

        // Price goes into Alice's position
        await validateSync(0);

        let upperTick = await hre.props.coverPool.ticks0(0);
        expect(upperTick.liquidityDelta).to.eq("33285024970969944913475");
        expect(upperTick.liquidityDeltaMinus).to.eq("0");

        // After going down to -20, tick 0 will be the cross tick and the liquidityDelta will be cleared
        await validateSync(-20);
        upperTick = await hre.props.coverPool.ticks0(0);
        expect(upperTick.liquidityDelta).to.eq("0");
        expect(upperTick.liquidityDeltaMinus).to.eq("0");

        // Pool has active liquidity once tick0 is crossed.
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("33285024970969944913475");

        // Go back up to tick 0. Since there is no liquidity delta on tick0 anymore, the system
        // will not kick in any liquidity into the pool for swapping.
        await validateSync(0);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("0");

        // Nothing gained from swap as no liquidity is active in the pool
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        });

        await validateSync(-20); 
        await validateSync(-40); 
        await validateSync(
            -60,
            true
        );

        // alice can now burn her position
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '0',
            liquidityAmount: aliceLiquidity,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(2),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: "",
        });

    });

    
    it("pool0 - multiple tick length jumps should not cause users to lose assets :: GUARDIAN AUDITS", async () => {
        // Note: unused, way to initialize all the ticks in the range manually
        let liquidityAmountBob = hre.ethers.utils.parseUnits("99855108194609381495771", 0);

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmountBob,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '60',
            claim: '60',
            upper: '80',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from("99655607520258884066351"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '100',
            claim: '100',
            upper: '120',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from("99456505428612725961158"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateBurn({
            signer: hre.props.bob,
            lower: '20',
            claim: '20',
            upper: '40',
            liquidityAmount: liquidityAmountBob,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        });

        await validateBurn({
            signer: hre.props.bob,
            lower: '60',
            claim: '60',
            upper: '80',
            liquidityAmount: BigNumber.from("99655607520258884066351"),
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        });

        await validateBurn({
            signer: hre.props.bob,
            lower: '100',
            claim: '100',
            upper: '120',
            liquidityAmount: BigNumber.from("99456505428612725961158"),
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        });

        await validateSync(-20);
        const liquidityAmount2 = hre.ethers.utils.parseUnits('16617549983581976690927', 0);
        liquidityAmountBob = hre.ethers.utils.parseUnits("99855108194609381495771", 0);

        const aliceLiquidityAmount = BigNumber.from('0')
        const bobLiquidityAmount = BigNumber.from('24951283310825598484485')

        // console.log("--------------- Alice First mint -------------");

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '0',
            claim: '0',
            upper: '120',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        // console.log("--------------- Sync 0 -------------");
        await validateSync(0)
        expect((await hre.props.coverPool.pool1()).liquidity).to.eq("16617549983581976690927");
        // console.log("--------------- Sync 20 -------------");
        await validateSync(20)
        expect((await hre.props.coverPool.pool1()).liquidity).to.eq("16617549983581976690927");

        // console.log("--------------- Sync 40 -------------");
        await validateSync(40);
        expect((await hre.props.coverPool.pool1()).liquidity).to.eq("16617549983581976690927");

        // console.log("--------------- Alice #1 burn ---------------");

        await validateBurn({
            signer: hre.props.alice,
            lower: '0',
            claim: '40',
            upper: '120',
            liquidityAmount: BigNumber.from('0'),
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('33266692264193520416'),
            lowerTickCleared: true,
            upperTickCleared: false,
            revertMessage: '',
        })

        // console.log("--------------- Sync $120 -------------");
        await validateSync(120);


        // console.log("--------------- Alice #2 Burn -------------");

        // When alice burns she realizes an errant loss of 50 out tokens.
        // This is because the syncLatest to 120 only increases the amountOutDelta
        // by an amount calculated from the tick 40 to tick 60 range, rather than the tick
        // 40 to tick 120 range.

        // The while loop for pool1 in syncLatest will only execute a single time since there
        // are no existing ticks between tick 40 and tick 120. In the _rollover for this
        // single execution the amountOutDelta will be constricted to the 40 to 60 range due to
        // line 343, where the if case fails and the currentPrice is not able to be set to the accumPrice.

        // The if case prevents amountDelta calculations from straddling the current pool.price.
        // One fix however is to allow such a straddling for the amountDelta in this particular scenario.

        // Another fix is to initialize the next tick before setting the nextTickToAccum when initializing the cache.
        // This way the while loop is able to continue for a second iteration and complete the rest of the range
        // that was previously curtailed due to the straddling.
        // This fix has been implemented in the syncLatest function, uncomment it and you will see that alice receives
        // all of her tokens back as expected.
        await validateBurn({
            signer: hre.props.alice,
            lower: '40',
            claim: '120',
            upper: '120',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('66733307735806479579'), // Notice Alice loses half her position!
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
    });

    it("pool0 - liquidity should not be locked due to Deltas.to calculation :: GUARDIAN AUDITS", async function () {
        await validateSync(20);

        // Alice creates a position from 0 to -20
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-20',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from("99955008249587388643769"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
            expectedUpper: '0',
        });

        // Bob creates a position from 0 to -20
        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-20',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from("99955008249587388643769"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
            expectedUpper: '0',
        });

        await validateSync(0);  // Trigger Auction from 0 -> -20

        // Active liquidity consists of liquidity which Alice and Bob provided.
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("199910016499174777287538");

        // User swaps in 10 tokens.
        // Now the pool should consist of 190 token0 and 10 token1.
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10), // Swap in 10 tokens
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10021521111719305613'),
            revertMessage: '',
        });

        await validateSync(-20);

        // Bob claims on lower tick
        await validateBurn({
            signer: hre.props.bob,
            lower: '-20',
            claim: '-20',
            upper: '0',
            liquidityAmount: BigNumber.from("99955008249587388643769"),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from("5000000000000000000"), // Get half of the 10 tokens swapped in
            balanceOutIncrease: BigNumber.from("94989239444140347192"), // ~(100 - 5)
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        });

        // Alice is unable to burn. Her liquidity is locked.
        // This is because Deltas.to performs `toTick.deltas.amountOutDelta += fromDeltas.amountOutDeltaMax`
        // instead of `toTick.deltas.amountOutDelta += fromDeltas.amountOutDelta`
        // As a result, the delta on the claim tick is larger than supposed to be 
        // and more tokens are sent to the user than intended. Around 100 token0 are attempted to
        // be sent to Alice although her allocation should only be about 95 token0.
        await validateBurn({
            signer: hre.props.alice,
            lower: '-20',
            claim: '-20',
            upper: '0',
            liquidityAmount: BigNumber.from("1"),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from("5000000000000000000"),
            balanceOutIncrease: BigNumber.from("94989239444140347193"), // This is the increase it ought to be it is actually 99999999999999999999
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: "",
        });

    });

    it("pool0 - amountOutDeltaMax should not underflow :: GUARDIAN AUDITS", async function () {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('49952516624167694475096')
        const bobLiquidityAmount = BigNumber.from('24951283310825598484485')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-80',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: bobLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        // await validateSync(0)
        await validateSync(-20);
        
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('74772840297597165330'),
            balanceOutIncrease: BigNumber.from('75012486881504305413'),
            revertMessage: '',
        });

        // Notice that Bob's burn reverts due to an underflow in the amountOutDeltaMax.
        // This is because the cache.finalDeltas.amountOutDelta is not removed from the
        // cache.finalDeltas.amountOutDeltaMax after it is shifted onto the cache.position.amountOut.
        // Once that value is decremented from the cache.finalDeltas.amountOutDeltaMax, the
        // burn can happen and Bob's funds are no longer locked.
        // When you uncomment the suggested line, the following burn no longer reverts & Bob receives
        // the expected amount of token0 & token1.
        // Without the suggestion, bobs funds are locked and he cannot retrieve them until
        // his position is fully filled.
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-20')).amountInDeltaMaxStashed.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-20')).amountOutDeltaMaxStashed.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountOutDeltaMax.toString())
        }

        await validateBurn({
            signer: hre.props.bob,
            lower: '-80',
            claim: '-20', // Bob claims partially through his position @ tick -20
            upper: '0',
            liquidityAmount: bobLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('24907659208740128448'),
            balanceOutIncrease: BigNumber.from('75012511866496001008'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        });

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20', // Alice claims partially through her position @ tick -20
            upper: '0',
            liquidityAmount: aliceLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('49865181088857036882'),
            balanceOutIncrease: BigNumber.from('49975001251999693576'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        });

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-20')).amountInDeltaMaxStashed.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-20')).amountOutDeltaMaxStashed.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountOutDeltaMax.toString())
        }

    });

    it("pool0 - Claim on stash tick; Mint again on start tick in same transaction :: alphak3y 313", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('33285024970969944913475')
        const aliceLiquidityAmount2 = BigNumber.from('99755307984763292988257')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10039063382085642276'),
            revertMessage: '',
        })

        await getTick(true, -20, debugMode)

        await validateSync(20)
        await getTick(true, -20, debugMode)
        await getLiquidity(true, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -20, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -40, debugMode)

        getTick(true, 0, debugMode)

        // minting with claim is the same outcome as burning with claim
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-40',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: BigNumber.from('43405733931640686251'), // alice gets amounOut back
            balanceOutIncrease: BigNumber.from('10000000000000000000'),
            liquidityIncrease: aliceLiquidityAmount,
            positionLiquidityChange: BigNumber.from('0'),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: ''
        })
        // await getTick(true, -40, debugMode)
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            liquidityAmount: aliceLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('33366670549555043973'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '', // Alice cannot claim at -20 when she should be able to
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '0',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '', // Alice cannot claim at -20 when she should be able to
        })
    });

    it("pool0 - Claim on stash tick; Mint after sync; Block overlapping position claim 312", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('33285024970969944913475')
        const aliceLiquidityAmount2 = BigNumber.from('99755307984763292988257')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10039063382085642276'),
            revertMessage: '',
        })

        await getTick(true, -20, debugMode)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('61630471922511652519'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })
        await validateSync(0)
        await getTick(true, -20, debugMode)
        await getLiquidity(true, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -20, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -40, debugMode)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        await getTick(true, -40, debugMode)
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('61630471922511652519'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: 'UpdatePositionFirstAt(-60, -40)', // Alice cannot claim until she closes her position at (-60, -40)
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            liquidityAmount: aliceLiquidityAmount2,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '', // Alice cannot claim until she closes her position at (-60, -40)
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: aliceLiquidityAmount.div(2).add(1),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('28330464695402705204'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '', // Alice cannot claim until she closes her position at (-60, -40)
        })

        // Alice cannot claim at this tick since the following tick, -40 is set in the EpochMap when syncing latest
        // -40 should only be set in the EpochMap if we successfully cross over it.
        // This can lead to users being able to claim amounts from ticks that have not yet actually
        // been crossed, potentially perturbing the pool accounting.
        // In addition to users not being able to claim their filled amounts as shown in this PoC.
    });

    it("pool0 - Claim on stash tick; Mint again on stash tick", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('33285024970969944913475')
        const aliceLiquidityAmount2 = BigNumber.from('99755307984763292988257')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10039063382085642276'),
            revertMessage: '',
        })

        await getTick(true, -20, debugMode)

        await validateSync(0)
        await getTick(true, -20, debugMode)
        await getLiquidity(true, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -20, debugMode)
        await getPositionLiquidity(true, alice.address, -60, -40, debugMode)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('73277601343136835738'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        await getTick(true, -40, debugMode)
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            liquidityAmount: aliceLiquidityAmount.div(2).add(1).add(aliceLiquidityAmount2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('116683335274777521987'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
    });

    it("pool0 - Users cannot claim at the right tick :: GUARDIAN AUDITS", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('49952516624167694475096')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10040071764942830081'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('89959928235057169918'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '', // Alice cannot claim at -20 when she should be able to
        })

        // Alice cannot claim at this tick since the following tick, -40 is set in the EpochMap when syncing latest
        // -40 should only be set in the EpochMap if we successfully cross over it.
        // This can lead to users being able to claim amounts from ticks that have not yet actually
        // been crossed, potentially perturbing the pool accounting.
        // In addition to users not being able to claim their filled amounts as shown in this PoC.
    });

    it("pool0 - twap rate-limiting yields invalid tick :: GUARDIAN AUDITS 58", async function () {
        await validateSync(20);

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-20',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from("99955008249587388643769"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        // Get an invalid latestTick by being rate limited.
        // The invalid tick results from the maxLatestTickMove not being a multiple of the tickSpread.
        // This occurs when the state.lastBlock - state.auctionStart is not a perfect multiple of the auctionLength.
        // Which will happen in the majority of cases.
        await validateSync(-20);

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-60',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: BigNumber.from("33366670549555043973"),
            liquidityIncrease: BigNumber.from("33285024970969944913475"),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
            expectedUpper: '-40'
        });

        // Notice that this swap occurs over the tick range -5 to -25
        // however alice's liquidity is used for this swap.
        // Additionally, the amountOut is greater than alice's liquidity -- meaning that the swapper
        // stole some of bob's liquidity when it wasn't in this range.
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from("0"),
            balanceOutIncrease: BigNumber.from('0'), // Greater than alice's "99955008249587388643769" liquidity
            revertMessage: '',
        });

        // Now if both alice and bob attempted to burn all of their liquidity, they could not remove it all.

        // Alice burns
        await validateBurn({
            signer: hre.props.alice,
            lower: '-20',
            claim: '-20',
            upper: '0',
            liquidityAmount: BigNumber.from("99955008249587388643769"), // Alice was already filled 100%
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        });

        // Bob burns & cannot burn his entire position
        await validateBurn({
            signer: hre.props.bob,
            lower: '-60',
            claim: '-25',
            upper: '-25',
            liquidityAmount: BigNumber.from("33285024970969944913475"),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()', // Bob cannot burn his entire position because the pool doesn't have all his tokens
        })

        await validateBurn({
            signer: hre.props.bob,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            liquidityAmount: BigNumber.from("33285024970969944913475"),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('33366670549555043972'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '', // Bob cannot burn his entire position because the pool doesn't have all his tokens
        })
    });

    it("pool0 - underflow when claiming for the second time :: GUARDIAN AUDITS 58", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('24951283310825598484485')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-80',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(0)
        await validateSync(-20)

        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("24951283310825598484485");

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('24907659208740128447'),
            balanceOutIncrease: BigNumber.from('24987488133503998990'),
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-20')).amountInDeltaMaxStashed.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-20')).amountOutDeltaMaxStashed.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountOutDeltaMax.toString())
        }

        await validateBurn({
            signer: hre.props.alice,
            lower: '-80',
            claim: '-20',
            upper: '0',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('24907659208740128447'),
            balanceOutIncrease: BigNumber.from('49987513124744754072'),
            lowerTickCleared: false,
            upperTickCleared: true,
            expectedUpper: '-40',
            revertMessage: '', 
        });

        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-20')).amountInDeltaMaxStashed.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-20')).amountOutDeltaMaxStashed.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-80')).deltas.amountOutDeltaMax.toString())
        }
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSync(-40);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSync(-60);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("12475641655412799242243");

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('12428948079035618256'),
            balanceOutIncrease: BigNumber.from('12518755307248153715'),
            revertMessage: '',
        });

        await validateSync(-80);

        await validateBurn({
            signer: hre.props.alice,
            lower: '-80',
            claim: '-80',
            upper: '-40',
            liquidityAmount: aliceLiquidityAmount.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('12428948079035618254'),
            balanceOutIncrease: BigNumber.from('12506243434503093220'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '', 
        });
    });

    it("pool0 - burn leading to division by 0 :: GUARDIAN AUDITS 61", async () => {
        await validateSync(20);
        const aliceLiquidityAmount = BigNumber.from('49952516624167694475096')
        const bobLiquidityAmount = BigNumber.from('24951283310825598484485')

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-80',
            claim: '0',
            upper: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: bobLiquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateSync(0);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("24951283310825598484485");

        await validateSync(-20);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("24951283310825598484485");

        await validateSync(0);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("0");
        // If we claim at 0 or -20 we do get out money back

        await validateSync(-40);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq("24951283310825598484485");

        await validateBurn({
            signer: hre.props.bob,
            lower: '-80',
            claim: '-40',
            upper: '0',
            liquidityAmount: bobLiquidityAmount,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999997'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        });

    });

    it('pool0 - should not have incorrect pool liquidity when final tick of position crossed :: GUARDIAN AUDITS', async function () {
        validateSync(0)
        const aliceLiquidityIncrease = BigNumber.from("49902591570441687020675")

        // Alice mints a position from -20 -> -60
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: aliceLiquidityIncrease,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        });

        await validateSync(-20);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq(aliceLiquidityIncrease);

        await validateSync(-40);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq(aliceLiquidityIncrease);

        // Stash liquidity delta on tick -60
        await validateSync(-20);
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq(0);

        await validateSync(-40);
        await validateSync(-60);
        // There is active liquidity at the end of Alice's position
        expect((await hre.props.coverPool.pool0()).liquidity).to.eq(BN_ZERO);

        // Swap being performed with Alice's liquidity at the end of her position
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: BigNumber.from('1'),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: 'WrongTickClaimedAt()',
        });

        await validateSync(-80);
        // Still can't burn
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: BigNumber.from('1'),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        });
    });

    it('pool0 - Should move TWAP in range, fill, sync lower tick, and clear stash deltas 57', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('49815343322651003239'),
            balanceOutIncrease: BigNumber.from('49975001251999693577'),
            revertMessage: '',
        })

        await validateSync(-40)

        //TODO: precision loss of 2 here

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('49815343322651003233'), //TODO: taking 2 extra out
            balanceOutIncrease: BigNumber.from('50024998748000306423'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateSync(-20)
        await validateSync(0)     
        
        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-40')).deltas.amountOutDeltaMax.toString())
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - sync multiple ticks at once and process claim 113', async function () {
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(-20)
        await validateSync(-40)
        await validateSync(-60)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-100)
        await validateSync(-60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: liquidityAmount2,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-120',
            upper: '-80',
            liquidityAmount: liquidityAmount2,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should process section1 claim on partial previous auction 114', async function () {
        //TODO: precision loss of 4 in this test
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(-60)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-80)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10100476017389330229'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: BN_ZERO,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10099423961650481309'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: BN_ZERO,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateSync(-100)
        await validateSync(-60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-100',
            upper: '-80',
            liquidityAmount: liquidityAmount2,
            zeroForOne: true,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-120',
            upper: '-80',
            liquidityAmount: liquidityAmount2,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('79800100020960188458'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountInDeltaMax.toString())
            //TODO: delta max of 2 left on tick
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should partially remove liquidity on second claim 115', async function () {
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(-60)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-80)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10100476017389330229'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: BN_ZERO,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: liquidityAmount2.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('44949761991305334886'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-120',
            claim: '-80',
            upper: '-80',
            liquidityAmount: liquidityAmount2.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('44949761991305334886'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-120')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should move TWAP in range, fill, sync lower tick, and clear tick deltas 25', async function () {
        const liquidityAmount4 = BigNumber.from('99805183140883374041350')
        const liquidityAmount5 = BigNumber.from('199710216389218762991542')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount.mul(2),
            zeroForOne: true,
            balanceInDecrease: tokenAmount.mul(2),
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount.mul(2),
            zeroForOne: true,
            balanceInDecrease: tokenAmount.mul(2),
            liquidityIncrease: liquidityAmount5,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        // await validateSwap({
        //     signer: hre.props.alice,
        //     recipient: hre.props.alice.address,
        //     zeroForOne: false,
        //     amountIn: tokenAmount.mul(2),
        //     priceLimit: BigNumber.from('79148977909814923576066331264'),
        //     balanceInDecrease: BigNumber.from('200000000000000000000'),
        //     balanceOutIncrease: BigNumber.from('200727459013899578577'),
        //     revertMessage: '',
        // })

        // await validateSync(-40)
        // await validateSync(-60)
        //TODO: precision loss of 1 on each tick sync
        await validateSync(-60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount5,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('6'),
            balanceOutIncrease: BigNumber.from('199999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        // liquidity not affected since the position is complete
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: liquidityAmount4.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'), 
            balanceOutIncrease: BigNumber.from('200000000000000000000').sub(2),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        // no liquidity left since we closed out and deleted the position
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: liquidityAmount4.div(2),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('254504143839762320698').div(2),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        await validateSync(-40)
        await validateSync(-20)

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            //TODO: delta max of 2 left on tick
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should dilute carry deltas during accumulate', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from('99755307984763292988257'),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.bob,
            lower: '-60',
            claim: '-60',
            upper: '-40',
            liquidityAmount: BigNumber.from('99755307984763292988257'),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999998'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateSync(-20)

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            //TODO: delta max of 2 left on tick
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
    })

    //TODO: add more liquidity after first claim

    it('pool0 - Should updateAccumDeltas during sync 26', async function () {
        const liquidityAmount4 = BigNumber.from('99855108194609381495771')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-40',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-60)
        await validateSync(-20)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
    })

    it('pool0 - Should move TWAP up and create stopTick0 during sync 27', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        const liquidityAmount5 = liquidityAmount4.div(2)

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: maxPrice,
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10041077831073905446'),
            revertMessage: '',
        })

        await validateSync(0)

        //TODO: precision off by one

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount5,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('5000000000000000000'),
            balanceOutIncrease: BigNumber.from('69966961710462894067'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4.sub(liquidityAmount5),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('74987500625999846788'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-40',
            liquidityAmount: liquidityAmount4.sub(liquidityAmount5),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('25012499374000153212'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.bob,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('5000000000000000000'),
            balanceOutIncrease: BigNumber.from('94979461084463047278'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool0 - Should move TWAP down and create nextLatestTick during sync 28', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-40)

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999998'), //TODO: precision off by a few
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (balanceCheck) {
            console.log('balance after token0:', (await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
            console.log('balance after token1:', (await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())
        }
        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks0('-60')).deltas.amountOutDeltaMax.toString())
        }
        
    })

    it('pool0 - Should claim multiple times on the same tick with a swap in between 29', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(-20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10040069750091208712'),
            revertMessage: '',
        })

        // collect on position

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10038045043818217528'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('20000000000000000000'),
            balanceOutIncrease: BigNumber.from('79921885206090573760'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
    })

    // move TWAP in range; no-op swap; burn immediately

    // multiple claims within current auction

    // move TWAP in range; no-op swap; move TWAP down tickSpread; burn liquidity

    // move TWAP in range; no-op swap; move TWAP down tickSpread; mint liquidity; burn liquidity

    // move TWAP in range; swap full amount; burn liquidity

    // move TWAP in range; swap full amount; mint liquidity; burn liquidity

    // move TWAP in range; swap partial amount; burn liquidity

    // move TWAP in range; swap partial amount; mint liquidity; burn liquidity

    // move TWAP and skip entire range; burn liquidity

    // move TWAP and skip entire range; mint more liquidity; burn liquidity

    // move TWAP and skip entire range; move TWAP back; burn liquidity

    // move TWAP and skip entire range; move TWAP back; mint liquidity; burn liquidity

    // move TWAP to unlock liquidity; partial fill; move TWAP down

    it('pool1 - Should mint/burn new LP position 23', async function () {
        // process two mints
        for (let i = 0; i < 2; i++) {
            await validateMint({
                signer: hre.props.alice,
                recipient: hre.props.alice.address,
                lower: '20',
                claim: '20',
                upper: '40',
                amount: tokenAmount,
                zeroForOne: false,
                balanceInDecrease: tokenAmount,
                liquidityIncrease: liquidityAmount,
                upperTickCleared: false,
                lowerTickCleared: false,
                revertMessage: '',
            })
        }

        // process no-op swap
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount,
            priceLimit: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        // process two burns
        for (let i = 0; i < 2; i++) {
            await validateBurn({
                signer: hre.props.alice,
                lower: '20',
                claim: '20',
                upper: '40',
                liquidityAmount: liquidityAmount,
                zeroForOne: false,
                balanceInIncrease: BN_ZERO,
                balanceOutIncrease: tokenAmount.sub(1),
                lowerTickCleared: false,
                upperTickCleared: false,
                revertMessage: '',
            })
        }

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            //TODO: delta max of 2 left on tick
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('40')).deltas.amountInDeltaMax.toString())
            //TODO: delta max of 2 left on tick
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should swap with zero output 12', async function () {
        // move TWAP to tick 0
        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.div(10),
            priceLimit: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '40',
            liquidityAmount: liquidityAmount,
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should move TWAP after mint and handle unfilled amount 13', async function () {
        const liquidityAmount2 = hre.ethers.utils.parseUnits('99955008249587388643769', 0)
        const balanceInDecrease = hre.ethers.utils.parseUnits('99750339674246044929', 0)
        const balanceOutIncrease = hre.ethers.utils.parseUnits('99999999999999999999', 0)

        // move TWAP to tick -20
        await validateSync(-20)

        // mint position
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '0',
            claim: '0',
            upper: '20',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        // move TWAP to tick 20
        await validateSync(0)
        await validateSync(20)

        // should revert on twap bounds
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidPositionBoundsTwap()',
        })

        // no-op swap
        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount,
            priceLimit: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        //burn should revert
        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '40',
            upper: '40',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        //valid burn
        await validateBurn({
            signer: hre.props.alice,
            lower: '0',
            claim: '20',
            upper: '20',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount.sub(1),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('20')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('20')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should not mint position below TWAP 10', async function () {
        await validateSync(40)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidPositionBoundsTwap()',
        })

        await validateSync(20)
    })

    it('pool1 - Should mint, swap, and then claim entire range 112', async function () {
        const lowerOld = hre.ethers.utils.parseUnits('0', 0)
        const lower = hre.ethers.utils.parseUnits('20', 0)
        const upperOld = hre.ethers.utils.parseUnits('887272', 0)
        const upper = hre.ethers.utils.parseUnits('40', 0)
        const amount = hre.ethers.utils.parseUnits('100', await hre.props.token0.decimals())
        const feeTaken = hre.ethers.utils.parseUnits('5', 16)

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.mul(2),
            priceLimit: minPrice,
            balanceInDecrease: BigNumber.from('99680524411508040121'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '40',
            upper: '40',
            liquidityAmount: liquidityAmount,
            zeroForOne: false,
            balanceInIncrease: BN_ZERO,
            balanceOutIncrease: tokenAmount,
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '40',
            liquidityAmount: liquidityAmount,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('99680524411508040121'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '40',
            liquidityAmount: liquidityAmount,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('99680524411508040121'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('40')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('40')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should move TWAP in range, partial fill, and burn 80', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        //TODO: 124905049859212811 leftover from precision loss

        await validateSync(0)

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '60',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(20)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.div(10),
            priceLimit: BigNumber.from('79307426338960776842885539846'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10040069750091208712'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '60',
            liquidityAmount: liquidityAmount4,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('89959930249908791288'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should revert for liquidity overflow 81', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        //TODO: 124905049859212811 leftover from precision loss

        await validateSync(0)

        await mintSigners20(hre.props.token1, tokenAmount.mul(10000000), [
            hre.props.alice,
            hre.props.bob,
        ])

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '60',
            amount: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            zeroForOne: false,
            balanceInDecrease: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'LiquidityOverflow()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '60',
            liquidityAmount: liquidityAmount4,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99875219786520339160'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('60')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('60')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - Should move TWAP in range by one, partial fill w/ max int128 of liquidity, and burn', async function () {
        const liquidityAmount4 = BigNumber.from('31849338570933576034964240875')
        /// @auditor -> this doesn't cause overflow...liquidity*values maxes out at 2.69e70...max uint256 is 1.15e77

        await validateSync(60)

        await mintSigners20(hre.props.token1, tokenAmount.mul(ethers.utils.parseUnits('34', 55)), [
            hre.props.alice,
            hre.props.bob,
        ])

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '600000',
            claim: '600000',
            upper: '600020',
            amount: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            zeroForOne: false,
            balanceInDecrease: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(600000)

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.div(10),
            priceLimit: minPrice,
            balanceInDecrease: BigNumber.from('2982576962873'),
            balanceOutIncrease: BigNumber.from('339999999999999999999999999997721907021'),
            revertMessage: '',
        })

        //TODO: swap has precision loss of 2278092979 or (6.7e-28) %

        await validateBurn({
            signer: hre.props.alice,
            lower: '600000',
            claim: '600000',
            upper: '600020',
            liquidityAmount: liquidityAmount4,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('2982576962873'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('600020')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('600020')).deltas.amountOutDeltaMax.toString())
        }
    })

    //TODO: these revert catches no longer work inside a library
    it('pool1 - mint position, move TWAP x2 w/ unfilled amounts, and check amountInDelta carry correctness 111', async function () {
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(20)
        await validateSync(40)
        await validateSync(60)
        

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '80',
            claim: '80',
            upper: '120',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        await validateSync(80)
        await validateSync(60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '80',
            claim: '100',
            upper: '120',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('100000000000000000000'),
            lowerTickCleared: true,
            upperTickCleared: false,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('claim tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('100')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('100')).deltas.amountOutDeltaMax.toString())
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('120')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('120')).deltas.amountOutDeltaMax.toString())
        }
    })

    it('pool1 - sync multiple ticks at once and process claim 112', async function () {
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(20)
        await validateSync(40)
        await validateSync(60)
        

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '80',
            claim: '80',
            upper: '120',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(100)

        await validateSync(60)

        await validateBurn({
            signer: hre.props.alice,
            lower: '80',
            claim: '120',
            upper: '120',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        if (deltaMaxAfterCheck) {
            console.log('final tick')
            console.log('deltainmax  after:', (await hre.props.coverPool.ticks1('120')).deltas.amountInDeltaMax.toString())
            console.log('deltaoutmax after:', (await hre.props.coverPool.ticks1('120')).deltas.amountOutDeltaMax.toString())
        }
    })

    // TODO: partial mint
    // TODO: ensure user cannot claim from a lower tick after TWAP moves around
    // TODO: claim liquidity filled
    // TODO: empty swap at price limit higher than current price
    // TODO: move TWAP again and fill remaining
    // TODO: claim final amount and burn LP position
    // TODO: mint LP position with priceLower < minPrice
    // TODO: P1 larger range; P2 smaller range; execute swap and validate amount returned by claiming
    // TODO: smaller range claims first; larger range claims first
    // TODO: move TWAP down and allow for new positions to be entered
    // TODO: no one can mint until observations are sufficient
    // TODO: fill tick, move TWAP down, claim, move TWAP higher, fill again, claim again

    // mint at different price ranges
    // mint then burn at different price ranges
    // mint swap then burn
    // collect
    //TODO: for price you can mint position instead of swapping and having a failed transaction
})
