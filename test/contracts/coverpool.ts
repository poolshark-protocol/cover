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
            lowerOld: '0',
            lower: '0',
            upper: '0',
            upperOld: '0',
            claim: '0',
            amount: tokenAmount,
            zeroForOne: true,
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
            zeroForOne: false,
            amountIn: tokenAmount,
            sqrtPriceLimitX96: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: 'WaitUntilEnoughObservations()',
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
            lowerOld: '0',
            lower: '0',
            upper: '0',
            upperOld: '0',
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
            sqrtPriceLimitX96: minPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: 'WaitUntilEnoughObservations()',
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
                lowerOld: '-887272',
                lower: '-40',
                claim: '-20',
                upper: '-20',
                upperOld: '0',
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
            sqrtPriceLimitX96: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

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
        // validate upper and lower ticks
        //TODO: move to validate mint/burn
        const lowerOld = hre.ethers.utils.parseUnits('-887272', 0)
        const lower = hre.ethers.utils.parseUnits('-40', 0)
        const upper = hre.ethers.utils.parseUnits('-20', 0)

        const lowerTickNode = await hre.props.coverPool.tickNodes(lower)
        const upperTickNode = await hre.props.coverPool.tickNodes(upper)
        expect(lowerTickNode.previousTick.toString()).to.be.equal('-887272')
        expect(lowerTickNode.nextTick.toString()).to.be.equal('-20')
        expect(upperTickNode.previousTick.toString()).to.be.equal('-40')
        expect(upperTickNode.nextTick.toString()).to.be.equal('0')
    })

    it('pool0 - Should mint, swap, and then claim entire range', async function () {
        await validateSync(hre.props.alice, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.alice, '-20')

        console.log((await hre.props.coverPool.pool0()).toString())

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            sqrtPriceLimitX96: maxPrice,
            balanceInDecrease: BigNumber.from('99670563335408299417'),
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
            balanceInIncrease: BigNumber.from('99670563335408299415'),
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

        console.log((await (hre.props.coverPool.ticks0("-20"))).toString())
    })

    it('pool0 - Should revert if tick not divisible by tickSpread', async function () {
        // move TWAP to tick 0
        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-30',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
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
            lowerOld: '-887272',
            lower: '-40',
            claim: '-10',
            upper: '-10',
            upperOld: '0',
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
        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
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
            sqrtPriceLimitX96: maxPrice,
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
    })

    it('pool0 - Should handle partial mint', async function () {
        const liquidityAmount3 = BigNumber.from('49952516624167694475096')
        const tokenAmount3 = BigNumber.from('50024998748000306423')
        // move TWAP to tick 0
        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '0',
            upper: '0',
            upperOld: '0',
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
            sqrtPriceLimitX96: maxPrice,
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
    })

    it('pool0 - Should move TWAP in range, partial fill, and burn', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        console.log('-60 tick after:', (await hre.props.coverPool.ticks0("-60")).toString())
        await validateSync(hre.props.admin, '-20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10041073354729183580'),
            revertMessage: '',
        })

        console.log('-20 tick before:', (await hre.props.coverPool.ticks0("-20")).toString())
        console.log('-60 tick after:', (await hre.props.coverPool.ticks0("-60")).toString())
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999998'),
            balanceOutIncrease: BigNumber.from('89958926645270816419'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
        console.log('-60 tick after:', (await hre.props.coverPool.ticks0("-60")).toString())
    })

    it('pool0 - Should handle partial range cross w/ unfilled amount 30', async function () {
        const liquidityAmount4 = BigNumber.from('49952516624167694475096')
        //TODO: 124905049859212811 leftover from precision loss
        console.log((await hre.props.coverPool.tickNodes("20")).toString())
        await validateSync(hre.props.admin, '20')
        console.log((await hre.props.coverPool.tickNodes("0")).toString())
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '0',
            upper: '0',
            upperOld: '20',
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
            sqrtPriceLimitX96: maxPrice,
            balanceInDecrease: BN_ZERO,
            balanceOutIncrease: BN_ZERO,
            revertMessage: '',
        })

        console.log((await hre.props.coverPool.tickNodes("20")).toString())
        await validateSync(hre.props.admin, '-20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: maxPrice,
            balanceInDecrease: tokenAmount.div(10),
            balanceOutIncrease: BigNumber.from('10041075369983633963'),
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
        console.log('-40 tick before:', (await hre.props.coverPool.ticks0("-40")).toString())
        await validateBurn({
            signer: hre.props.alice,
            lower: '-40',
            claim: '-20',
            upper: '0',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999998'),
            balanceOutIncrease: BigNumber.from('89958924630016366036'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })

        console.log('-40 tick after:', (await hre.props.coverPool.ticks0("-40")).toString())
    })

    it('pool0 - Should move TWAP in range, partial fill, sync lower tick, and burn 30', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        console.log('-40 tick before:', (await hre.props.coverPool.ticks0("-40")).toString())
        await validateSync(hre.props.admin, '0')
        console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())
        await validateSync(hre.props.admin, '-20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331265'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10041073354729183580'),
            revertMessage: '',
        })

        console.log('-20 tick before:', (await hre.props.coverPool.ticks0("-20")).toString())

        await validateSync(hre.props.admin, '-40')

        console.log('-40 tick before:', (await hre.props.coverPool.ticks0("-40")).toString())
        console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-20',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999998'),
            balanceOutIncrease: BigNumber.from('89963946174270869537'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateSync(hre.props.admin, '-60')

        // console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('9999999999999999998'),
            balanceOutIncrease: BigNumber.from('89963946174270869537'),
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
            balanceOutIncrease: BigNumber.from('89958926645270816419'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
    })

    it('pool0 - Should move TWAP in range, fill, sync lower tick, and clear carry deltas 24', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })
        console.log('-20 tick before:', (await hre.props.coverPool.ticks0("-20")).toString())
        await validateSync(hre.props.admin, '-20')
        console.log('-20 tick before:', (await hre.props.coverPool.ticks0("-20")).toString())

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('49810365274745445180'),
            balanceOutIncrease: BigNumber.from('49975001251999693577'),
            revertMessage: '',
        })

        console.log('-40 node before:', (await hre.props.coverPool.tickNodes("-40")).toString())
        console.log('-60 node before:', (await hre.props.coverPool.tickNodes("-60")).toString())
        console.log('-20 tick after:', (await hre.props.coverPool.ticks0("-20")).toString())
        await validateSync(hre.props.admin, '-40')
        console.log('-20 tick after:', (await hre.props.coverPool.ticks0("-20")).toString())
        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '-60',
        //     claim: '-20',
        //     upper: '-20',
        //     liquidityAmount: liquidityAmount4,
        //     zeroForOne: true,
        //     balanceInIncrease: BigNumber.from('9999999999999999997'),
        //     balanceOutIncrease: BigNumber.from('89963946174270869537'),
        //     lowerTickCleared: false,
        //     upperTickCleared: false,
        //     revertMessage: 'WrongTickClaimedAt()',
        // })
        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('49810365274745445176'),
            balanceOutIncrease: BigNumber.from('50024998748000306422'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })
        // console.log('-20 tick after:', (await hre.props.coverPool.ticks0("-20")).toString())
        // console.log('-40 tick after:', (await hre.props.coverPool.ticks0("-40")).toString())
        // console.log('-60 tick after:', (await hre.props.coverPool.ticks0("-60")).toString())
    })

    it('pool0 - Should move TWAP in range, fill, sync lower tick, and clear tick deltas 25', async function () {
        const liquidityAmount4 = BigNumber.from('99855108194609381495771')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '-20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.mul(2),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('99670563335408299417'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            revertMessage: '',
        })

        // await validateSync(hre.props.admin, '-40')

        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '-40',
        //     claim: '-20',
        //     upper: '-20',
        //     liquidityAmount: liquidityAmount4,
        //     zeroForOne: true,
        //     balanceInIncrease: BigNumber.from('9999999999999999997'),
        //     balanceOutIncrease: BigNumber.from('89963946174270869537'),
        //     lowerTickCleared: false,
        //     upperTickCleared: false,
        //     revertMessage: 'WrongTickClaimedAt()',
        // })

        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '-40',
        //     claim: '-40',
        //     upper: '-20',
        //     liquidityAmount: liquidityAmount4,
        //     zeroForOne: true,
        //     balanceInIncrease: BigNumber.from('99670563335408299416'),
        //     balanceOutIncrease: BigNumber.from('0'),
        //     lowerTickCleared: true,
        //     upperTickCleared: true,
        //     revertMessage: '',
        // })
    })

    it.skip('pool0 - Should dilute carry deltas during accumulate 25', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '-20')

        await validateMint({
            signer: hre.props.bob,
            recipient: hre.props.bob.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-40',
            upper: '-40',
            upperOld: '-20',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: BigNumber.from('99755307984763292988257'),
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())

        await validateSync(hre.props.admin, '-40')

        await validateSync(hre.props.admin, '-60')

        console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-60',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999998'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })

        // console.log('-60 tick before:', (await hre.props.coverPool.ticks0("-60")).toString())

        await validateBurn({
            signer: hre.props.bob,
            lower: '-60',
            claim: '-60',
            upper: '-40',
            liquidityAmount: BigNumber.from('99755307984763292988257'),
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
    })

    it.skip('pool0 - Should updateAccumDeltas during sync 26', async function () {
        const liquidityAmount4 = BigNumber.from('99855108194609381495771')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-40',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '-60')

        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '-40',
        //     claim: '-40',
        //     upper: '-20',
        //     liquidityAmount: liquidityAmount4.mul(2),
        //     zeroForOne: true,
        //     balanceInIncrease: BigNumber.from('99720423547181890362'),
        //     balanceOutIncrease: BigNumber.from('0'),
        //     lowerTickCleared: false,
        //     upperTickCleared: false,
        //     revertMessage: '',
        // })
    })

    it('pool0 - Should move TWAP up and create stopTick0 during sync 27', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '-20')

        await validateSync(hre.props.admin, '0')

        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '-40',
        //     claim: '-40',
        //     upper: '-20',
        //     liquidityAmount: liquidityAmount4.mul(2),
        //     zeroForOne: true,
        //     balanceInIncrease: BigNumber.from('99720423547181890362'),
        //     balanceOutIncrease: BigNumber.from('0'),
        //     lowerTickCleared: false,
        //     upperTickCleared: false,
        //     revertMessage: '',
        // })
    })

    it.skip('pool0 - Should move TWAP down and create nextLatestTick during sync 28', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '-40')

        await validateBurn({
            signer: hre.props.alice,
            lower: '-60',
            claim: '-40',
            upper: '-20',
            liquidityAmount: liquidityAmount4,
            zeroForOne: true,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999999'),
            lowerTickCleared: false,
            upperTickCleared: true,
            revertMessage: '',
        })
    })

    it.skip('pool0 - Should claim multiple times on the same tick with a swap in between 29', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-887272',
            lower: '-60',
            claim: '-20',
            upper: '-20',
            upperOld: '0',
            amount: tokenAmount,
            zeroForOne: true,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        console.log('-40 tick before:', (await hre.props.coverPool.tickNodes("-40")).toString())

        await validateSync(hre.props.admin, '-20')

        console.log('-40 tick after:', (await hre.props.coverPool.tickNodes("-40")).toString())

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10041073354729183580'),
            revertMessage: '',
        })

        // collect on position

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: false,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: BigNumber.from('79148977909814923576066331264'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10042057447019805010'),
            revertMessage: '',
        })

        console.log('-40 tick after:', (await hre.props.coverPool.tickNodes("-40")).toString())

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
            balanceInIncrease: BigNumber.from('19999999999999999998'),
            balanceOutIncrease: BigNumber.from('79916869198251011408'),
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
                lowerOld: '0',
                lower: '20',
                claim: '20',
                upper: '40',
                upperOld: '887272',
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
            sqrtPriceLimitX96: maxPrice,
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
    })

    it('pool1 - Should swap with zero output 12', async function () {
        // move TWAP to tick 0
        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '40',
            upperOld: '887272',
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
            sqrtPriceLimitX96: minPrice,
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
    })

    it('pool1 - Should move TWAP after mint and handle unfilled amount 13', async function () {
        const liquidityAmount2 = hre.ethers.utils.parseUnits('99955008249587388643769', 0)
        const balanceInDecrease = hre.ethers.utils.parseUnits('99750339674246044929', 0)
        const balanceOutIncrease = hre.ethers.utils.parseUnits('99999999999999999999', 0)

        // move TWAP to tick -20
        await validateSync(hre.props.alice, '-20')

        // mint position
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '-20',
            lower: '0',
            claim: '0',
            upper: '20',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        // move TWAP to tick 20
        await validateSync(hre.props.alice, '20')

        // should revert on twap bounds
        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '40',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidPositionBoundsTwap()',
        })

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount,
            sqrtPriceLimitX96: minPrice,
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
            balanceOutIncrease: tokenAmount.sub(2),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
    })

    it('pool1 - Should not mint position below TWAP 10', async function () {
        await validateSync(hre.props.alice, '40')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '40',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: 'InvalidPositionBoundsTwap()',
        })
    })

    it('pool1 - Should mint, swap, and then claim entire range 17', async function () {
        const lowerOld = hre.ethers.utils.parseUnits('0', 0)
        const lower = hre.ethers.utils.parseUnits('20', 0)
        const upperOld = hre.ethers.utils.parseUnits('887272', 0)
        const upper = hre.ethers.utils.parseUnits('40', 0)
        const amount = hre.ethers.utils.parseUnits('100', await hre.props.token0.decimals())
        const feeTaken = hre.ethers.utils.parseUnits('5', 16)

        await validateSync(hre.props.alice, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '40',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.alice, '20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.mul(2),
            sqrtPriceLimitX96: minPrice,
            balanceInDecrease: BigNumber.from('99670563335408299416'),
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
            balanceInIncrease: BigNumber.from('99670563335408299415'),
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
            balanceInIncrease: BigNumber.from('99670563335408299415'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'NotEnoughPositionLiquidity()',
        })
    })

    it('pool1 - Should move TWAP in range, partial fill, and burn 80', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        //TODO: 124905049859212811 leftover from precision loss

        await validateSync(hre.props.admin, '0')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '60',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '20')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: BigNumber.from('79307426338960776842885539846'),
            balanceInDecrease: BigNumber.from('10000000000000000000'),
            balanceOutIncrease: BigNumber.from('10041073354729183580'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '20',
            claim: '20',
            upper: '60',
            liquidityAmount: liquidityAmount4,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('9988056890417576364'), //TODO: validate this number is correct
            balanceOutIncrease: BigNumber.from('89958926645270816419'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
    })

    it('pool1 - Should revert for liquidity overflow 81', async function () {
        const liquidityAmount4 = BigNumber.from('49902591570441687020675')
        //TODO: 124905049859212811 leftover from precision loss

        await validateSync(hre.props.admin, '0')

        await mintSigners20(hre.props.token1, tokenAmount.mul(10000000), [
            hre.props.alice,
            hre.props.bob,
        ])

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '0',
            lower: '20',
            claim: '20',
            upper: '60',
            upperOld: '887272',
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
    })

    it.skip('pool1 - Should move TWAP in range by one, partial fill w/ overflow on newPrice, and burn', async function () {
        const liquidityAmount4 = BigNumber.from('31849338570933576034964240875')
        /// @auditor -> this doesn't cause overflow...liquidity*values maxes out at 2.69e70...max uint256 is 1.15e77

        await validateSync(hre.props.admin, '60')

        await mintSigners20(hre.props.token1, tokenAmount.mul(ethers.utils.parseUnits('34', 55)), [
            hre.props.alice,
            hre.props.bob,
        ])

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '60',
            lower: '600000',
            claim: '600000',
            upper: '600020',
            upperOld: '887272',
            amount: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            zeroForOne: false,
            balanceInDecrease: tokenAmount.mul(ethers.utils.parseUnits('34', 17)),
            liquidityIncrease: liquidityAmount4,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '600000')

        await validateSwap({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            zeroForOne: true,
            amountIn: tokenAmount.div(10),
            sqrtPriceLimitX96: minPrice,
            balanceInDecrease: BigNumber.from('2984665930559'),
            balanceOutIncrease: BigNumber.from('339999999999999999999999999997721907021'),
            revertMessage: '',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '600000',
            claim: '600000',
            upper: '600020',
            liquidityAmount: liquidityAmount4,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('2984665184391'),
            balanceOutIncrease: BigNumber.from('0'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: '',
        })
    })

    //TODO: these revert catches no longer work inside a library
    it.skip('pool1 - mint position, move TWAP x2 w/ unfilled amounts, and check amountInDeltaCarryPercent correctness 111', async function () {
        const liquidityAmount2 = BigNumber.from('49753115595468372952776')
        const liquidityAmount3 = BigNumber.from('99456505428612725961158')
        await validateSync(hre.props.admin, '60')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lowerOld: '60',
            lower: '80',
            claim: '80',
            upper: '120',
            upperOld: '887272',
            amount: tokenAmount,
            zeroForOne: false,
            balanceInDecrease: tokenAmount,
            liquidityIncrease: liquidityAmount2,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        await validateSync(hre.props.admin, '100')

        await validateSync(hre.props.admin, '60')

        await validateBurn({
            signer: hre.props.alice,
            lower: '80',
            claim: '100',
            upper: '120',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999998'),
            lowerTickCleared: false,
            upperTickCleared: false,
            revertMessage: 'WrongTickClaimedAt()',
        })

        await validateBurn({
            signer: hre.props.alice,
            lower: '80',
            claim: '120',
            upper: '120',
            liquidityAmount: liquidityAmount2,
            zeroForOne: false,
            balanceInIncrease: BigNumber.from('0'),
            balanceOutIncrease: BigNumber.from('99999999999999999997'),
            lowerTickCleared: true,
            upperTickCleared: true,
            revertMessage: '',
        })
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
