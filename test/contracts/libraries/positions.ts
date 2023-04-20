import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { IRangePool } from '../../../typechain'
import { PoolState, BN_ZERO } from '../../utils/contracts/coverpool'
import { gBefore } from '../../utils/hooks.test'
import { mintSigners20 } from '../../utils/token'

describe('Positions Library Tests', function () {
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
})
