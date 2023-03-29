import { SUPPORTED_NETWORKS } from './scripts/constants/supportedNetworks'
import {
    DEPLOY_COVERPOOL,
    DEPLOY_COVERPOOLS,
    INCREASE_SAMPLES,
    MINT_POSITION,
    MINT_TOKENS,
    VERIFY_CONTRACTS,
} from './tasks/constants/taskNames'
import { purpleLog } from './test/utils/colors'

export function handleHardhatTasks() {
    handleCoverPoolTasks()
}

function handleCoverPoolTasks() {
    // for (const network in SUPPORTED_NETWORKS) {
    //     if (Object.keys(LOCAL_NETWORKS).includes(network)) continue;
    //     hre.masterNetwork = MASTER_NETWORKS[network];
    //     break;
    // }
    if (process.argv.includes(DEPLOY_COVERPOOLS)) {
        import('./tasks/deploy/deploy-coverpools')
        logTask(DEPLOY_COVERPOOLS)
    } else if (process.argv.includes(DEPLOY_COVERPOOL)) {
        import('./tasks/deploy/deploy-coverpool')
        logTask(DEPLOY_COVERPOOL)
    } else if (process.argv.includes(INCREASE_SAMPLES)) {
        import('./tasks/deploy/increase-samples')
        logTask(INCREASE_SAMPLES)
    } else if (process.argv.includes(MINT_TOKENS)) {
        import('./tasks/deploy/mint-tokens')
        logTask(MINT_TOKENS)
    } else if (process.argv.includes(MINT_POSITION)) {
        import('./tasks/deploy/mint-position')
        logTask(MINT_POSITION)
    } else if (process.argv.includes(VERIFY_CONTRACTS)) {
        import('./tasks/deploy/verify-contracts')
        logTask(VERIFY_CONTRACTS)
    }
}

function logTask(taskName: string) {
    purpleLog(`\n🎛  Running ${taskName} task...\n`)
}
