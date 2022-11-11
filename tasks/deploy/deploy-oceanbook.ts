import { task } from 'hardhat/config';
import { GetBeforeEach } from '../../test/utils/setup/beforeEachProps';
import { DEPLOY_OCEANBOOK } from '../constants/taskNames';
import { DeployOceanBook } from './utils/deployOceanBook';

class DeployOceanBookTask {
    public deployOceanBook: DeployOceanBook;
    public getBeforeEach: GetBeforeEach;

    constructor() {
        this.deployOceanBook = new DeployOceanBook();
        this.getBeforeEach = new GetBeforeEach();
        hre.props = this.getBeforeEach.retrieveProps();
    }
}

task(DEPLOY_OCEANBOOK)
    .setDescription('Deploys OceanBook')
    .setAction(async function ({
        ethers
    }) {
        const deployOceanBook: DeployOceanBookTask = new DeployOceanBookTask();

        if (!deployOceanBook.deployOceanBook.canDeploy()) return;

        await deployOceanBook.deployOceanBook.preDeployment();

        await deployOceanBook.deployOceanBook.runDeployment();

        await deployOceanBook.deployOceanBook.postDeployment();

        console.log('OceanBook deployment complete.\n');
});
