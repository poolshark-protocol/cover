import { InitialSetup } from '../../../test/utils/setup/initialSetup'
import { mintSigners20 } from '../../../test/utils/token'
import { getNonce } from '../../utils'

export class MintTokens {
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
        console.log('running address:', hre.props.alice.address)
        if (hre.network.name == 'hardhat') {
            hre.props.bob = signers[1]
            hre.carol = signers[2]
        }
        hre.nonce = await getNonce(hre, hre.props.alice.address)
        console.log(this.nonce)
        await this.initialSetup.readCoverPoolSetup(this.nonce)
        const token0Amount = ethers.utils.parseUnits('1000', 6)
        // const token1Amount = ethers.utils.parseUnits('1000', await hre.props.token1.decimals())
        // await mintSigners20(hre.props.token0, token0Amount.mul(10), [hre.props.alice], ['0xCa2A59A26dDfd56C69e3465DF66ee2986B4B0F4a'])
        // await mintSigners20(hre.props.token1, token0Amount.mul(10), [hre.props.alice], ['0xCa2A59A26dDfd56C69e3465DF66ee2986B4B0F4a'])
        // '0xEbfF7a98149b4774c9743C5D1f382305Fe5422c9'
        await hre.props.token20Batcher.mintBatch(
            ['0xEbfF7a98149b4774c9743C5D1f382305Fe5422c9'],
            [
               '0x0e1b285d86e581d02BB54050F4CC178193F91332'
            ], token0Amount.mul(1), {gasLimit: 80_000_000})

        //TODO: take in address parameter
        // const token0Balance = await hre.props.token0.balanceOf(
        //     '0x50924f626d1Ae4813e4a81E2c5589EC3882C13ca'
        // )
        // console.log(
        //     '0x50924f626d1Ae4813e4a81E2c5589EC3882C13ca',
        //     'token 0 balance:',
        //     token0Balance.toString()
        // )
        // const token1Balance = await hre.props.token1.balanceOf(
        //     '0x50924f626d1Ae4813e4a81E2c5589EC3882C13ca'
        // )
        // console.log(
        //     '0x50924f626d1Ae4813e4a81E2c5589EC3882C13ca',
        //     'token 1 balance:',
        //     token1Balance.toString()
        // )
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
