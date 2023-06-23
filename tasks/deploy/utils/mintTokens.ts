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
                '0x7bEeba96a6EaBfbc9ceF5C8a5CF4E28fD4223fcF',
  '0xdC1ab035004Fe9D88a308eBaf6417509accb37c2',
  '0x1E66DfC2FC49Ba3A323812AeCEbcf50C7b2D64A9',
  '0xEADa8ABE36f600da7100eEd8912B5796B9661deC',
  '0xC0E36199a29043363A373a8f02b6cc8ab40389cb',
  '0x07f8eA7a012fD8d7786567523afA4873993cbB05',
  '0x13D46EF5a38716552D35A0840e7F884cAcDCcfA6',
  '0x41F15eD259C34229088223FE53Af573b7b662e97',
  '0xeeE072349A531CbD66BA9fD1a6d55197a1Fc022b',
  '0x617bAF6d0A841752ce986b3638EA148B49077443',
  '0x8062c241C47CD83dbA22d210f9a2D4A8d25674E6',
  '0x7c8bDD1F91c6638522C6961F334A106b66F59cf0',
  '0xD111886cb7eFF60F390E8F4C4F7c288C21988d51',
  '0x4A1f2a1Fc4ab466D2ef210B8B74521690AC8332A',
  '0x8636D4Bae80F6B5141aA57aBfd672B274Bc0F0F6',
  '0x548d9422e865cf782c6485D175F3B9AD4D34643C',
  '0x767A60F295AEDd958932088F9Cd6a4951D8739b6',
  '0x90A992b583590A2f539FDa0B4b82629F9d4F1346',
  '0xAf21bCBe9bC68f3555942c23069158fa7e19B9c1',
  '0xF9868b3960348194371B8cA4Fe87Ca7DE95e40b6',
  '0x6fd2a8e6Ec8Aed694506620734905567d0745636',
  '0x8A2FA09530F858D2B064d5539aa755E8b901033a',
  '0x2bd5D10d5994a19e5E911379753A7EbC50119D5B',
  '0x6F6932C87Ddc4Ea4B6c9001A8C007344430F233a',
  '0x268e0d7811A711Fc0f2735cBc62C1572D05bF70A',
  '0x71799D107Df028d5A5D0a11a726969E7DF71B4AB',
  '0x9b327BC6616fF854Ef9f78C477F368b929d9dF2D',
  '0x2Af4b96fB69DC868eCd385865501460611AEaC4C',
  '0x3683C3a1777d7921eF83EeA56DdF6c7a7654ea5D',
  '0x0e1b285d86e581d02BB54050F4CC178193F91332',
  '0xb8141b34075E55F3fc2cb8De9733acD7177E8829',
  '0x6cAf2385F08114DC8948C26580B2041Bd5bb50c0',
  '0xd6D1d688f613CfAa20E450482268963cd90D32C5',
  '0x06887698291516f0F1A8aa51C24cE9c4DF9ae0d6',
  '0xA1a26c50382f10e112328D793f76B2D84Ba87D4A',
  '0xCda329d290B6E7Cf8B9B1e4faAA48Da80B6Fa2F2',
  '0x465d8F5dB6aBfdAE82FE95Af82CbeC538ec5337b',
              ], token0Amount.mul(100), {gasLimit: 20000000})

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
