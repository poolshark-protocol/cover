import { task } from 'hardhat/config'
import { GetBeforeEach } from '../../test/utils/setup/beforeEachProps'
import { DEPLOY_COVERPOOL } from '../constants/taskNames'
import { DeployCoverPool } from '../deploy/utils/deployCoverPool'

class DeployCoverPoolTask {
    public deployCoverPool: DeployCoverPool
    public getBeforeEach: GetBeforeEach

    constructor() {
        this.deployCoverPool = new DeployCoverPool()
        this.getBeforeEach = new GetBeforeEach()
        hre.props = this.getBeforeEach.retrieveProps()
    }
}

task(DEPLOY_COVERPOOL)
    .setDescription('Deploys Cover Pool')
    .setAction(async function ({ ethers }) {
        const deployCoverPool: DeployCoverPoolTask = new DeployCoverPoolTask()

        if (!deployCoverPool.deployCoverPool.canDeploy()) return

        await deployCoverPool.deployCoverPool.preDeployment()

        await deployCoverPool.deployCoverPool.runDeployment()

        await deployCoverPool.deployCoverPool.postDeployment()

        console.log('Cover pool deployment complete.\n')
    })
