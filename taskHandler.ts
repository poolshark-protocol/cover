import { DEPLOY_HEDGEPOOLS } from './tasks/constants/taskNames';
import { purpleLog } from './test/utils/colors';

export function handleHardhatTasks() {
    handleOrderBook20Tasks();
}

function handleOrderBook20Tasks() {
    if (process.argv.includes(DEPLOY_HEDGEPOOLS)) {
        import('./tasks/deploy/deploy-hedgepools');
        logTask(DEPLOY_HEDGEPOOLS);
    }
}

function logTask(taskName: string) {
    purpleLog(`\n🎛  Running ${taskName} task...\n`);
}
