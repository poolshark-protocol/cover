import { BigNumber } from 'ethers'
import { BN_ZERO, getLatestTick, getLiquidity, getPrice, validateBurn, validateMint, validateSwap, validateSync } from '../../../test/utils/contracts/coverpool'
import { InitialSetup } from '../../../test/utils/setup/initialSetup'
import { mintSigners20 } from '../../../test/utils/token'
import { getNonce } from '../../utils'

export class MintPosition {
    private initialSetup: InitialSetup
    private nonce: number

    constructor() {
        this.initialSetup = new InitialSetup()
    }

    public async preDeployment() {
        //clear out deployments json file for this network
    }

    public async runDeployment() {
        const signers = await ethers.getSigners()
        hre.props.alice = signers[0]
        console.log(hre.network.name)
        if (hre.network.name == 'hardhat') {
            hre.props.bob = signers[1]
            hre.carol = signers[2]
        }
        hre.nonce = await getNonce(hre, hre.props.alice.address)
        console.log(this.nonce)
        await this.initialSetup.readCoverPoolSetup(this.nonce)
        console.log('read positions')
        const token0Amount = ethers.utils.parseUnits('100', await hre.props.token0.decimals())
        const token1Amount = ethers.utils.parseUnits('100', await hre.props.token1.decimals())
        await mintSigners20(hre.props.token0, token0Amount.mul(10), [hre.props.alice], [hre.props.alice.address])
        await mintSigners20(hre.props.token1, token1Amount.mul(10), [hre.props.alice], [hre.props.alice.address])

        const liquidityAmount = BigNumber.from('199760153929825488153727')

        await getLatestTick(true)

        // await getPrice(true)
        // 0x65f5B282E024e3d6CaAD112e848dEc3317dB0902
        // 0x1DcF623EDf118E4B21b4C5Dc263bb735E170F9B8
        // 0x9dA9409D17DeA285B078af06206941C049F692Dc
        // 0xBd5db4c7D55C086107f4e9D17c4c34395D1B1E1E
        const txn = await hre.props.poolRouter.createCoverPoolAndMint(
            {
                poolType: ethers.utils.formatBytes32String("PSHARK-CPROD"),
                tokenIn: '0x0bfaaafa6e8fb009cd4e2bd3693f2eec2d18b053',
                tokenOut: '0xEbfF7a98149b4774c9743C5D1f382305Fe5422c9',
                feeTier: "1000",
                tickSpread: "20",
                twapLength: "12"
            },
            []
        , {gasLimit: 3_000_000})

        await txn.wait();

        return;
        await validateMint({
            signer: hre.props.alice,
            recipient: '0x65f5B282E024e3d6CaAD112e848dEc3317dB0902',
            lower: '73400', //1096
            upper: '73600', //1211
            amount: token1Amount,
            zeroForOne: true,
            balanceInDecrease: token1Amount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

        //         await validateSwap({
        // signer: hre.props.alice,
        // recipient: hre.props.alice.address,
        // zeroForOne: true,
        // amountIn: token1Amount.div(10000),
        // priceLimit: BigNumber.from('79228162514264337593543950336'),
        // balanceInDecrease: token1Amount.mul(30),
        // balanceOutIncrease: token1Amount.mul(30),
        // revertMessage:''
        // })

        // await validateBurn({
        //     signer: hre.props.alice,
        //     lower: '60',
        //     claim: '60',
        //     upper: '100',
        //     liquidityPercent: ethers.utils.parseUnits('1', 38),
        //     zeroForOne: false,
        //     balanceInIncrease: BN_ZERO,
        //     balanceOutIncrease: token1Amount.sub(1),
        //     lowerTickCleared: false,
        //     upperTickCleared: false,
        //     revertMessage: '',
        // })

        // await validateSync(78240)

        await getPrice(false, true)
        await getLiquidity(false, true)
        await getLatestTick(true)

        console.log('position minted')
    }

    public async postDeployment() {}

    public canDeploy(): boolean {
        let canDeploy = true

        if (!hre.network.name) {
            console.log('❌ ERROR: No network name present.')
            canDeploy = false
        }

        return canDeploy
    }
}
