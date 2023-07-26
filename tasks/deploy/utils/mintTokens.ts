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
        const token0Amount = ethers.utils.parseUnits('100', await hre.props.token0.decimals())
        const token1Amount = ethers.utils.parseUnits('100', await hre.props.token1.decimals())
        // await mintSigners20(hre.props.token0, token0Amount.mul(10), [hre.props.alice], ['0xCa2A59A26dDfd56C69e3465DF66ee2986B4B0F4a'])
        // await mintSigners20(hre.props.token1, token0Amount.mul(10), [hre.props.alice], ['0xCa2A59A26dDfd56C69e3465DF66ee2986B4B0F4a'])
        await hre.props.token20Batcher.mintBatch(
            [hre.props.token0.address, hre.props.token1.address], 
            [
                '0xE61aBAFe6AbD96809AD2505F521E7E02ceC41764',
                '0x4DD72586fFe14a915ef757b0E9a0c4019932BcA2',
                '0xF7128274D8Ec9D25694E34912beAB3d4B2F50130',
                '0xaaea48d32fa9c930c4a64e343325f3784bbdea05',
                '0xF8C44D4c2BC63AacA7E6EcFd7763effF71A3444C',
                '0x46c754738F78454690C04c6F416858aEF8B46eeE',
                '0xc05ED8F3adbC1007d9d8dEbc21a721Aa951FAD50',
                '0x2b7403bdB196fa5fc0e4f779600A084bE0D8422E',
                '0xB0a6C408d37AeC2A58a041919F895cb24d4088f1',
                '0xc600a005F9a948F9D44B4B7937a3Dfc7182b238C',
                '0x693542F61eBcE90a4F37f6491CC6B0e73F0a2fB3',
                '0x5FBce71b1b74d0d8511dC708ceED3250a1aBDacA',
                '0x03AC7CaA058026BaaA09a1285F2a9990892b64F0',
                '0x7bEeba96a6EaBfbc9ceF5C8a5CF4E28fD4223fcF',
                '0xdC1ab035004Fe9D88a308eBaf6417509accb37c2',
                '0x1E66DfC2FC49Ba3A323812AeCEbcf50C7b2D64A9',
                '0xEADa8ABE36f600da7100eEd8912B5796B9661deC',
                '0xC0E36199a29043363A373a8f02b6cc8ab40389cb',
                '0x07f8eA7a012fD8d7786567523afA4873993cbB05',
                '0x2bd5D10d5994a19e5E911379753A7EbC50119D5B',
                '0x6F6932C87Ddc4Ea4B6c9001A8C007344430F233a',
                '0x268e0d7811A711Fc0f2735cBc62C1572D05bF70A',
                '0x71799D107Df028d5A5D0a11a726969E7DF71B4AB',
                '0x9b327BC6616fF854Ef9f78C477F368b929d9dF2D',
                '0x06887698291516f0F1A8aa51C24cE9c4DF9ae0d6',
                '0xA1a26c50382f10e112328D793f76B2D84Ba87D4A',
                '0xCda329d290B6E7Cf8B9B1e4faAA48Da80B6Fa2F2',
                '0x465d8F5dB6aBfdAE82FE95Af82CbeC538ec5337b',
                '0xBd5db4c7D55C086107f4e9D17c4c34395D1B1E1E',
                '0x4ED5f34cf458f0E2a42a514E1B1b846637Bd242E',
                '0xaE312276Ea1B35C68617441beddc0d0Fd13c1aF2',
                '0x39e9259Aa9d1bf05f5E285BE7acA91Eefe694094',
                '0x34e800D1456d87A5F62B774AD98cea54a3A40048',
                '0x1DcF623EDf118E4B21b4C5Dc263bb735E170F9B8',
                '0xF2bE526eE1242C0e9736CF0E03d834C71389A4c7',
                '0x1b5e17110463b3a2da875bc68934EB5137A4f6f4',
                '0x20A13F1e2638c9784a031F291943b2A87B3f12A6',
                '0x69e8e23Eb2e61BC8449e02Ced7075186DAFBcFc1',
                '0x5bcb86339f2B53CA52EdAdc4C692199a78f06E71',
                '0xFb408FA20c6f6DA099a7492107bC3531911896e3',
                '0x4fd787803dB60816F16B121cC7c5637263f1736f',
                '0xB7b60698a41e2375A700a37A46fFCEE42c202c13',
            ], token0Amount.mul(10), {gasLimit: 20000000})

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
