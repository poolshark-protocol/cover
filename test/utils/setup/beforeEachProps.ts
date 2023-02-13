import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { getNonce } from '../../../tasks/utils'
import {
    RangeFactoryMock,
    RangePoolMock,
    DyDxMath,
    FullPrecisionMath,
    CoverPool,
    CoverPoolFactory,
    Positions,
    TickMath,
    Ticks,
    Token20,
    TwapOracle,
    Epochs,
} from '../../../typechain'
import { InitialSetup } from './initialSetup'

export interface BeforeEachProps {
    coverPool: CoverPool
    coverPoolFactory: CoverPoolFactory
    rangeFactoryMock: RangeFactoryMock
    rangePoolMock: RangePoolMock
    tickMathLib: TickMath
    dydxMathLib: DyDxMath
    epochsLib: Epochs
    fullPrecisionMathLib: FullPrecisionMath
    ticksLib: Ticks
    twapOracleLib: TwapOracle
    positionsLib: Positions
    tokenA: Token20
    tokenB: Token20
    token0: Token20
    token1: Token20
    token20: Token20
    admin: SignerWithAddress
    alice: SignerWithAddress
    bob: SignerWithAddress
    carol: SignerWithAddress
}

export class GetBeforeEach {
    private initialSetup: InitialSetup
    private nonce: number

    constructor() {
        this.initialSetup = new InitialSetup()
    }

    public async getBeforeEach() {
        hre.props = this.retrieveProps()
        const signers = await ethers.getSigners()
        hre.props.admin = signers[0]
        hre.props.alice = signers[0]
        if (hre.network.name == 'hardhat') {
            hre.props.bob = signers[1]
            hre.carol = signers[2]
        }
        hre.nonce = await getNonce(hre, hre.props.alice.address)
        this.nonce = await this.initialSetup.initialCoverPoolSetup()
    }

    public retrieveProps(): BeforeEachProps {
        let coverPool: CoverPool
        let coverPoolFactory: CoverPoolFactory
        let rangeFactoryMock: RangeFactoryMock
        let rangePoolMock: RangePoolMock
        let tickMathLib: TickMath
        let dydxMathLib: DyDxMath
        let epochsLib: Epochs
        let fullPrecisionMathLib: FullPrecisionMath
        let ticksLib: Ticks
        let twapOracleLib: TwapOracle
        let positionsLib: Positions
        let tokenA: Token20
        let tokenB: Token20
        let token0: Token20
        let token1: Token20
        let token20: Token20
        let admin: SignerWithAddress
        let alice: SignerWithAddress
        let bob: SignerWithAddress
        let carol: SignerWithAddress

        return {
            coverPool,
            coverPoolFactory,
            rangeFactoryMock,
            rangePoolMock,
            tickMathLib,
            dydxMathLib,
            epochsLib,
            fullPrecisionMathLib,
            ticksLib,
            twapOracleLib,
            positionsLib,
            tokenA,
            tokenB,
            token0,
            token1,
            token20,
            admin,
            alice,
            bob,
            carol,
        }
    }
}
