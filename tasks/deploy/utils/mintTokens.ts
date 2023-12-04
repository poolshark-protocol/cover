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
        // await mintSigners20(hre.props.token1, token0Amount.mul(1000), [hre.props.alice], ['0xBd5db4c7D55C086107f4e9D17c4c34395D1B1E1E'])
        // '0xEbfF7a98149b4774c9743C5D1f382305Fe5422c9'
        // '0x0BfaaAfa6e8fB009cD4e2Bd3693F2EEC2d18B053'
        // '0x19beE8e887a5db5cf20A841eb4DAACBCacF14B1b'
        await hre.props.token20Batcher.mintBatch(
            ['0xEbfF7a98149b4774c9743C5D1f382305Fe5422c9',],
            [     '0x6a88027bBFC1393f1Ed19fa2A9300C3953aC8b98',//
            '0xDc3cCAF326C8ff29a3177805eE87fB0251914309',
            '0x07f8eA7a012fD8d7786567523afA4873993cbB05',
            '0xf89d78D330434e110b0B5C27b8308d225142Da03',
            '0x9B837d0C951a34d565231bED1F9c20772f80e27A',
            '0x043Be57cA9A428762C68C6A13cC1266512589E7D',
            '0xf46bCfa955c7380E1A9748975428E04E624D1cC9',
            '0x106E06bD8dF139ac4A105fC0d6277fb68b39FA3a',
            '0x7b042c22A39c651Fb6e516928cD5F5179cD9d4DB',
            '0x63440DE92C437967aA08EC0Dd51850FF7FD94aff',
            '0xc689A1cf9Ca0D3db7713345D42BEb4B132d8aE32',
            '0x8106C8c338B0D86a78Ae9011Ba717e8eaa3Ae9d4',
            '0x6b2f58614a8d43829e210e17b1F504EFe0d2eD17', //
            '0xa3f9bd4F103F600E5886eE80708372ECC646a036',
            '0x44c614dE52a51E6eA0360906E55d717Fa8C5eB3E',
            '0x671E83971F543fa4C3E533df4b55838c6aeb2c45',
            '0x1846Fb3E55069d144715709dF1C5433E780f9053',
            '0x547814d5c60c72ba8B55955bc8A046536FbD77eE',
            '0x2e4f0e9240E9240a54d352e90F4CB614bB18C6f7',
            '0x45d993393f7B3Fe781935e1155118C7f830d4415',
            '0x0c1d5aa8930ff99d735bb5fc1265d3108d09729f',
            '0x2eb6896CE4F45192140b5321F61D11E9eDA82F2B',
            '0x8847EBaaf29A18396e49191602f8d8D141b98aa7',
            '0x664Fae4E52981d3eb5f0E2BDa615A0E4B057F0DE',
            '0x2bB4a1Dc852b02eE3a3446cA624aD343b6eEEaA6',
            '0x64d196e9cc62ec70ca0379dfc38ccbff344dd38b',
            '0x410360b9dCA14DF852Fe2818b57aD4e9d2b7Bc45',
            '0x6fCD3561C603cc72b15357caF59C0e579f5C1B03',
            '0xC48520Bdf117d951E495225B77EB38734Be96d94',
            '0x24E1921f04D3c0AA707bcd588225ccFe1C53493d',
            '0x8F76c82F572D97C7b7D773dB62E64b4f0b61B253',
            '0x5125889AaB1Ab5dBDD399eFe7f5734e44Db07f56',
            '0x860732d54034CdE25E9Dd579E7e36184F04f4548',
            '0xe52bA6F91811439854b85CE79a9C65e8911c13aC',
            '0xd435231Bed0D4DE8541D94Ec93e1E094Ae633b72',
            '0x4dA792b5058F59162E1B619749a0Ce4E984D4841',
            '0x547814d5c60c72ba8B55955bc8A046536FbD77eE',
            '0xCa9ba74eE20917211ef646AC51ACcc287F27538b',
            '0x9AE4F4a3efea60a1d73cb32476A8697E057473BB',
            '0x33275f4B8de6571e7650305CbCfCbeeba5fcF4B5',
            '0x71ac680233DFA6d8a10600D077Df9bE89e19aaC7',
            '0xc63671075D54f73f47fb437528d8643b3D7701C4',
            '0xA99DA68da256437215264005605E125973E793Ad',
            '0x000f4432a40560bBFf1b581a8b7AdEd8dab80026',
            '0x01d0C05F9a9b74CEBF8Fcf2BBfa2257A50708929',
            '0x000F38c11De32dF3BFD065c37Eec99a00a42546f',
            '0x4b3a832dB69d467819267C04cc632f7636C05Dcc',
            '0x315fFf7C53D75737D5a9F5165beD76ca1f689c73',
            '0x8bC0dbe3B09bCb20470763143352cB8Cb0238181',
            '0x34d6C8F98846e773177519cB59C197caD17A12C9',
            '0x148F4e63611be189601f1F1555d4C79e8cEBddC8',
            '0x9A810B1cEaF50759693c288D5DB485938663A462',
            '0xad2429c165eE3c9E282FF5c9E41045eBe2Aa9044',
            '0x01F8B9484B95f9e118a5b0593E513bDba47Ad7Da',
            '0x74F0bD24d03F8D444fCa820Fa022964a0eB56eb8',
            '0x84533181eb327EbfCcFd2439e8C4966d7260be5b',
            '0xAd50B95c9305488dC4444Deb39C6a102Df59D7AE',
            '0xcd34746eAc14E60F666E3cEE9d7991D045bBf761',
            '0x57FC1299a7FE49882E9593BA79a6E650c2e3F9D0',
            '0x72E5d8D85Db805C275561D9FCE16C11002c676FE',
            '0x72E5d8D85Db805C275561D9FCE16C11002c676FE',
            '0x42a831A7279C8De5DEea822627E8991b904653a9',
            '0xe08583e015f358ce59489DEba17B9774833C9F8E',
            '0x287c07066A0430223a7a02D6695F067dF518Ba5e',
            '0x07d095Ff9fCF13e086ab6D44309733E95DAa28c3',
            '0xb9AAd7fb7D0854a4bD55Cca2c8c606fDA499f7B9',
            '0x88c736cCee4cf398297a764f2fe2aAF7e6937D7b',
            '0x8c952cc18969129A1C67297332A0B6558eB0bFEc',
            '0x9eFEb581C020Fc746C1df51d8d2e829C03aA6674',
            '0x1b4C396f3F25b86c33FFDe1E7F6afCAeBDD3ddF4',
            '0x5881d9BfFf787C8655A9b7F3484aE1a6f7a966E8',
            '0x5df12FaD79F630DC7c64D3BD2C00673F4ef36682',
            '0x7b042c22A39c651Fb6e516928cD5F5179cD9d4DB',
            '0xc689A1cf9Ca0D3db7713345D42BEb4B132d8aE32',
            '0x720B451a9c21908DeDA19D92E55895847Bec043d',
            '0x8c90e009A6567eA39fE1443Ae3aB03c0EB80Cc11',
            '0x659835D141416Cb9c868Ae99486A58Ee214140cD',
            '0xBe317BcadDFD00106977e17420427BC8D0101F05',
            '0x10C292a9B4b0D085e71590B67F99408a38F3e40a',
            '0x1DfE222F72B87Ca8bF2e1414c3B2F952B0F73B62',
            '0x8522442BE81c98F18C63Ab6446f9De11481F4F92',
            '0xc195F2726352165A1C628cd08833aaF837d76924',
            '0x10D8614a4De958A5831F6b015604864E30252a30',
            '0x943f12dF9afA19DB3b67888aBd9EaE4465eb7c8d',
            '0xF23BE978a2Fa4d91D6E3A9E62120dD069cF1c733',
            '0x6d3E6D2f1546dBF6E691b17Af425c6124D1Dc374',
            '0x62f1511269AAc24e79BF6F5172ca661711C7dC23',
            '0x8446DfE7f0c8d5Db618E8264cC6ed15b7a91c66b',
            '0x465d8F5dB6aBfdAE82FE95Af82CbeC538ec5337b',
            '0x7A8583Db42EF87E618a4879b18a58FA62E462bF4',
            '0x69978da94A19E96C4DD44bc13b693CF83057B9a1',
            '0xF40efeF7a98502B33c1BeE076c886795BAbcA02C',
            '0xe1E281bC6a1B6b12B775d8b08A829c4ecCeD4B35',
            '0x734ef1765588150677F26F4Ebb43d7d3326A9Eaa',
            '0x503596528878b9603534c8a43363FE4ea5A89262',
            '0xc4735b87dFb6c7cC3651677651E4bF139B27Cc59',
            '0x8F90628fBF475dEd16a83071eDCD1D21B764017D',
            '0x85B2Ca334f2E6dC60428ce663575aA96F81F7256',
            '0x4692C5fE408879c96f0d94D1814c690434f550c0',
            '0x573aDaD94A5d502E14A772488Dea8FBf30ECd47E',
            '0x515b754d8b51E08F7a4BB0d804C047d63fa4FD27',
            '0x8B2B8601124CDFa264558169473A2c12f2ddaa50',
            '0x010fFce4B90d552Ec754B7B37DBA9bF49C1Ad3e9',
            '0xAe14Daa3Ec60a5EC30c83ffC3f3f3d7553D7973D',
            '0x478e78583A27972845971fA1bf1e43fBBF14d7F0',
            '0x35CB5ABD6d3B8911291B06477a61691FaA407265',
            '0xe8D79Ded7c683Edbe868aC5c7EC3016B9687Db02',
            '0x2cFDFD87eF82ebAEB6603a1124de410ADf72bE65',
            '0x28581D2854fBc981DBC9eA109105D73A70c527E7',
            '0xAf61B0f9756163709A129F60c2192876365D13D5',
            '0xd516ACf12120a0Aa34CA3D835F688dA9195BAbc3',
            '0x0A01715CF0D6728e16f753F61d447eE580e35558',
            '0xaE0BF45abf324f15E00bEe2D5b5D8e7612e50a32',
            '0xa303Fe338F7E412d90ff27BA3FCe1903B0c885Bc',
            '0x54372fd91473e0F6F8507A955CD45De9B9D740D5',
            '0x0874827c91c24d337854fB3e8c701088Cd9881d3',
            '0x6DDe50a4ABF87193C2aba53153Ef1734C5A192BA',
            '0x33DdF6B07804ECf8BC378A4B197002F02078E7EB',
            '0x7C058598da8998599CD5477B1646dE0Fc5839049',
            '0x1049c923fF19FA5088d2466F942A1dAa79D03d85',
            '0x1d75Ccf1E886a203c8f84e0A7b68475CF8bD2c6a',
            '0xc92eF6b1426Be8fCB048831ab0555e1577a16E28',
            '0xED5A42f58d5dBDE7e0cC122416A3540De6ccc6C3',
            '0x8A8C879D39A74fCE0593714956bB7Ed048A5c1BF',
            '0x0949C8d6aa7aD809ea08216f327ecF8a3C6B6518',
            '0x8bC0dbe3B09bCb20470763143352cB8Cb0238181',
            '0x8bC0dbe3B09bCb20470763143352cB8Cb0238181',
            '0xa1e0699E73C1523a788bf2058Be68196c933D1E1',
            '0x14d1a955e2467ee8D04d747EeD647c7966E6AC06',
            '0x7C1c510878768Ab7A37dF92411Dee3244967F5c6',
            '0xa8EB650d195B8c271d16Bdd80DFa0dC54A0FC27A',
            '0x5320A72B8EEcDa26be1eE9E0245d39D53979D1a0',
            '0x69cE139860Bb9162DC3356d48495Cbf90299F5EF',
            '0x2d209040c031d4e2D4d9cb4D3aabf18F52260AB0',
            '0x507bFAaEDB3394d0c5aeE8170ebce209057A6Cce',
            '0x05Aff7939E8072ab2eA03306A099EFF2516aFe6F',
            '0x4236c9f574057c6530067e1FDD9AC6c08c8287fd',
            '0x1D97170895cf2a7788DF357e67071beA821b296C',
            '0x59A337056D8f5FCbB900d8Ad3268002a11587F1d',
            '0x004A014984904D48fE450db8dEB9289aC27F427D',
            '0xABBb979bAe05506E018FAA1e7aa12582C00988A4',
            '0x814101E949f2690Ee7c5BEc7e7817C1A72bf09c4',
            '0xc13E2dB13C132c05895997a05A6b0474543961bE',
            '0xF671a0945586c3bF398f5a0bF5Ade9436DC89B1f',
            '0x9FBC318fb93821b36dE5b0344bA1E522a5d5D7Ba',
            '0x416cE32e56bEA5Df1D5B1D81aA1761C7433bC6B7',
            '0x6b2f58614a8d43829e210e17b1F504EFe0d2eD17',
            '0xe08583e015f358ce59489DEba17B9774833C9F8E',], token0Amount.mul(1), {gasLimit: 80_000_000})

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
