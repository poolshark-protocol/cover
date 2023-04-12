import { BigNumber } from 'ethers'
import { validateMint } from '../../../test/utils/contracts/coverpool'
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
        const token0Amount = ethers.utils.parseUnits('100', await hre.props.token0.decimals())
        const token1Amount = ethers.utils.parseUnits('100', await hre.props.token1.decimals())
        await mintSigners20(hre.props.token0, token0Amount.mul(10), [hre.props.alice])
        await mintSigners20(hre.props.token1, token1Amount.mul(10), [hre.props.alice])

        const liquidityAmount = BigNumber.from('199760153929825488153727')

        await validateMint({
            signer: hre.props.alice,
            recipient: hre.props.alice.address,
            lower: '20',
            claim: '20',
            upper: '40',
            amount: token1Amount.mul(10),
            zeroForOne: false,
            balanceInDecrease: token1Amount,
            liquidityIncrease: liquidityAmount,
            upperTickCleared: false,
            lowerTickCleared: false,
            revertMessage: '',
        })

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
