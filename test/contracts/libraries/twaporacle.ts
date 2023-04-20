import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { IRangePool } from '../../../typechain'
import { PoolState, BN_ZERO } from '../../utils/contracts/coverpool'
import { gBefore } from '../../utils/hooks.test'
import { mintSigners20 } from '../../utils/token'

describe('TwapOracle Library Tests', function () {
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

    it('Should return false for isPoolObservationsEnough', async function () {
        await hre.props.rangePoolMock.setObservationCardinality('4')

        expect(
            await hre.props.twapOracleLib.isPoolObservationsEnough(
                hre.props.rangePoolMock.address,
                '5'
            )
        ).to.be.equal(false)

        await hre.props.rangePoolMock.setObservationCardinality('5')
    })

    it('Should return true for isPoolObservationsEnough', async function () {
        await hre.props.rangePoolMock.setObservationCardinality('5')

        expect(
            await hre.props.twapOracleLib.isPoolObservationsEnough(
                hre.props.rangePoolMock.address,
                '5'
            )
        ).to.be.equal(true)
    })
})
