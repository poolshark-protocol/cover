import { task } from 'hardhat/config'
import { GetBeforeEach } from '../../test/utils/setup/beforeEachProps'
import { INCREASE_SAMPLES } from '../constants/taskNames'
import { IncreaseSamples } from '../deploy/utils/increaseSamples'

class IncreaseSamplesTask {
    public deployCoverPools: IncreaseSamples
    public getBeforeEach: GetBeforeEach

    constructor() {
        this.deployCoverPools = new IncreaseSamples()
        this.getBeforeEach = new GetBeforeEach()
        hre.props = this.getBeforeEach.retrieveProps()
    }
}

task(INCREASE_SAMPLES)
    .setDescription('Increase Twap Sample Length on Mock Pool')
    .setAction(async function ({ ethers }) {
        const deployCoverPools: IncreaseSamplesTask = new IncreaseSamplesTask()

        if (!deployCoverPools.deployCoverPools.canDeploy()) return

        await deployCoverPools.deployCoverPools.preDeployment()

        await deployCoverPools.deployCoverPools.runDeployment()

        await deployCoverPools.deployCoverPools.postDeployment()

        console.log('Hedge pool deployment complete.\n')
    })
