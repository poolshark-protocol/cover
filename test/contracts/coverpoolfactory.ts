/* global describe it before ethers */
const hardhat = require('hardhat')
const { expect } = require('chai')
import { gBefore } from '../utils/hooks.test'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber } from 'ethers'

alice: SignerWithAddress
describe('CoverPoolFactory Tests', function () {
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

    before(async function () {
        await gBefore()
    })

    this.beforeEach(async function () {})

    it('Should not create pool with identical token address', async function () {
        await expect(
            hre.props.coverPoolFactory
                .connect(hre.props.admin)
                .createCoverPool({
                    poolType: uniV3String,
                    tokenIn: '0x0000000000000000000000000000000000000000',
                    tokenOut: '0x0000000000000000000000000000000000000000',
                    feeTier: '500',
                    tickSpread: '20',
                    twapLength: '5'
            })
        ).to.be.revertedWith('InvalidTokenAddress()')
    })

    it('Should not create pool with invalid twap source', async function () {
        await expect(
            hre.props.coverPoolFactory
                .connect(hre.props.admin)
                .createCoverPool({
                    poolType: ethers.utils.formatBytes32String('test'),
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: '500',
                    tickSpread: '20',
                    twapLength: '5'
                })
        ).to.be.revertedWith('PoolTypeNotFound()')
    })

    it('Should not create pool if the pair already exists', async function () {
        await expect(
            hre.props.coverPoolFactory
                .connect(hre.props.admin)
                .createCoverPool({
                    poolType: uniV3String,
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: '500',
                    tickSpread: '20',
                    twapLength: '5'
                })
        ).to.be.revertedWith('PoolAlreadyExists()')
    })

    it('Should not create pool if volatility tier does not exist', async function () {
        await expect(
            hre.props.coverPoolFactory
                .connect(hre.props.admin)
                .createCoverPool({
                    poolType: uniV3String,
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: '2000',
                    tickSpread: '20',
                    twapLength: '5'
                })
        ).to.be.revertedWith('VolatilityTierNotSupported()')
    })
})
