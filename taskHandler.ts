import { DEPLOY_HEDGEPOOLS, MINT_POSITION, MINT_TOKENS } from './tasks/constants/taskNames';
import { purpleLog } from './test/utils/colors';

export function handleHardhatTasks() {
    handleOrderBook20Tasks();
}

function handleOrderBook20Tasks() {
    if (process.argv.includes(DEPLOY_HEDGEPOOLS)) {
        import('./tasks/deploy/deploy-hedgepools');
        logTask(DEPLOY_HEDGEPOOLS);
    } else if (process.argv.includes(MINT_TOKENS)) {
        import('./tasks/deploy/mint-tokens');
        logTask(MINT_TOKENS);
    } else if (process.argv.includes(MINT_POSITION)) {
        import('./tasks/deploy/mint-position');
        logTask(MINT_POSITION);
    }
}

function logTask(taskName: string) {
    purpleLog(`\n🎛  Running ${taskName} task...\n`);
}
