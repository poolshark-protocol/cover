import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { IRangePool } from '../../../typechain'
import { PoolState, BN_ZERO } from '../../utils/contracts/coverpool'
import { gBefore } from '../../utils/hooks.test'
import { mintSigners20 } from '../../utils/token'

describe('FullPrecisionMath Library Tests', function () {
    let token0Amount: BigNumber
    let token1Amount: BigNumber
    let token0Decimals: number
    let token1Decimals: number
    let currentPrice: BigNumber

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress

    //TODO: mint position and burn as if there were 100

    before(async function () {
        await gBefore()
    })

    this.beforeEach(async function () {})

    it('divRoundingUp - Should round up', async function () {
        expect(
            await hre.props.fullPrecisionMathLib.divRoundingUp(
                BigNumber.from('5'),
                BigNumber.from('4')
            )
        ).to.be.equal(BigNumber.from('2'))
    })

    it('divRoundingUp - Should revert on uint256 max', async function () {
        await expect(
            hre.props.fullPrecisionMathLib.mulDivRoundingUp(
                BigNumber.from(
                    '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
                ),
                BigNumber.from('2'),
                BigNumber.from('1')
            )
        ).to.be.revertedWith('Transaction reverted: library was called directly')
    })

    it('divRoundingUp - Should handle rounding up', async function () {
        expect(
            await hre.props.fullPrecisionMathLib.mulDivRoundingUp(
                ethers.utils.parseUnits('2', 70),
                BigNumber.from('1'),
                BigNumber.from('3')
            )
        ).to.be.equal(
            BigNumber.from('6666666666666666666666666666666666666666666666666666666666666666666667')
        )
    })
})
