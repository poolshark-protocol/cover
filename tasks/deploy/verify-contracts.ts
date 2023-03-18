import { task } from 'hardhat/config'
import { GetBeforeEach } from '../../test/utils/setup/beforeEachProps'
import { DEPLOY_COVERPOOLS, VERIFY_CONTRACTS } from '../constants/taskNames'
import { VerifyContracts } from './utils/verifyContracts'

class VerifyContractsTask {
    public deployCoverPools: VerifyContracts
    public getBeforeEach: GetBeforeEach

    constructor() {
        this.deployCoverPools = new VerifyContracts()
        this.getBeforeEach = new GetBeforeEach()
        hre.props = this.getBeforeEach.retrieveProps()
    }
}

task(VERIFY_CONTRACTS)
    .setDescription('Verifies all contracts')
    .setAction(async function ({ ethers }) {
        const deployCoverPools: VerifyContractsTask = new VerifyContractsTask()

        if (!deployCoverPools.deployCoverPools.canDeploy()) return

        await deployCoverPools.deployCoverPools.preDeployment()

        await deployCoverPools.deployCoverPools.runDeployment()

        await deployCoverPools.deployCoverPools.postDeployment()

        console.log('Contract verification complete.\n')
    })
