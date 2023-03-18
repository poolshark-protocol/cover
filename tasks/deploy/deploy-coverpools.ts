import { task } from 'hardhat/config'
import { GetBeforeEach } from '../../test/utils/setup/beforeEachProps'
import { DEPLOY_COVERPOOLS } from '../constants/taskNames'
import { DeployCoverPools } from './utils/deployCoverPools'

class DeployCoverPoolsTask {
    public deployCoverPools: DeployCoverPools
    public getBeforeEach: GetBeforeEach

    constructor() {
        this.deployCoverPools = new DeployCoverPools()
        this.getBeforeEach = new GetBeforeEach()
        hre.props = this.getBeforeEach.retrieveProps()
    }
}

task(DEPLOY_COVERPOOLS)
    .setDescription('Deploys Cover Pools')
    .setAction(async function ({ ethers }) {
        const deployCoverPools: DeployCoverPoolsTask = new DeployCoverPoolsTask()

        if (!deployCoverPools.deployCoverPools.canDeploy()) return

        await deployCoverPools.deployCoverPools.preDeployment()

        await deployCoverPools.deployCoverPools.runDeployment()

        await deployCoverPools.deployCoverPools.postDeployment()

        console.log('Cover pool deployment complete.\n')
    })
