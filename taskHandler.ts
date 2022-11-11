import { CREATE_BOOK_1155_TO_20, CREATE_BOOK_20, DEPLOY_FACTORY_1155_TO_20, DEPLOY_FACTORY_20, DEPLOY_OCEANBOOK, DEPLOY_ROUTER_1155_TO_20, DEPLOY_ROUTER_20, LIMIT_ORDER_1155_TO_20, LIMIT_ORDER_20, QUOTE_OUT_20 } from './tasks/constants/taskNames';
import { purpleLog } from './test/utils/colors';

export function handleHardhatTasks() {
    handleOrderBook20Tasks();
}

function handleOrderBook20Tasks() {
    if (process.argv.includes(DEPLOY_FACTORY_20)) {
        import('./tasks/contracts/exchange/factory/orderbookfactory20');
        logTask(DEPLOY_FACTORY_20);
    } else if (process.argv.includes(DEPLOY_ROUTER_20)) {
        import('./tasks/contracts/exchange/router/orderbookrouter20');
        logTask(DEPLOY_ROUTER_20);
    } else if (process.argv.includes(CREATE_BOOK_20)) {
        import('./tasks/contracts/exchange/factory/orderbookfactory20');
        logTask(CREATE_BOOK_20);
    } else if (process.argv.includes(LIMIT_ORDER_20)) {
        import('./tasks/contracts/exchange/book/orderbook20');
        logTask(LIMIT_ORDER_20);
    } else if (process.argv.includes(QUOTE_OUT_20)) {
        import('./tasks/contracts/exchange/book/orderbook20');
        logTask(QUOTE_OUT_20);
    } else if (process.argv.includes(DEPLOY_FACTORY_1155_TO_20)) {
        import('./tasks/contracts/exchange/factory/orderbookfactory1155to20');
        logTask(DEPLOY_FACTORY_1155_TO_20);
    } else if (process.argv.includes(DEPLOY_ROUTER_1155_TO_20)) {
        import('./tasks/contracts/exchange/router/orderbookrouter1155to20');
        logTask(DEPLOY_ROUTER_1155_TO_20);
    } else if (process.argv.includes(CREATE_BOOK_1155_TO_20)) {
        import('./tasks/contracts/exchange/factory/orderbookfactory1155to20');
        logTask(CREATE_BOOK_1155_TO_20);
    } else if (process.argv.includes(LIMIT_ORDER_1155_TO_20)) {
        import('./tasks/contracts/exchange/book/orderbook1155to20');
        logTask(LIMIT_ORDER_1155_TO_20);
    } else if (process.argv.includes(DEPLOY_OCEANBOOK)) {
        import('./tasks/deploy/deploy-oceanbook');
        logTask(DEPLOY_OCEANBOOK);
    }
}

function logTask(taskName: string) {
    purpleLog(`\n🎛  Running ${taskName} task...\n`);
}
