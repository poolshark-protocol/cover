import { task } from "hardhat/config";
import { createBook20 } from "../../../../test/utils/contracts/exchange/factory/orderbookfactory20";
import { CREATE_BOOK_20, DEPLOY_FACTORY_20 } from "../../../constants/taskNames";
import { deployOrderBookFactory20, deployToken20 } from "../../../deploy/deploy20";
import { getWalletAddress, getNonce } from "../../../utils";

task(DEPLOY_FACTORY_20, "deploy factory for OrderBook20")
.setAction(async (args, hre) => {
  if(process.env.PRIVATE_KEY == undefined){
    return;
  }
  const accountAddress = await getWalletAddress(hre, process.env.PRIVATE_KEY);
  let nonce = await getNonce(hre, accountAddress);

  await deployOrderBookFactory20(hre, nonce);
});

task(CREATE_BOOK_20, "create OrderBook20 contract from factory")
  .setAction(async (args, hre) => {
    if(process.env.PRIVATE_KEY == undefined){
      return;
    }
    const accountAddress = await getWalletAddress(hre, process.env.PRIVATE_KEY);
    let nonce = await getNonce(hre, accountAddress);
    
    const tokenAName = "Token20A"; const tokenASymbol = "TOKEN20A";

    const tokenA = await deployToken20(hre, nonce, tokenAName, tokenASymbol, 18);

    nonce += 1;

    const tokenBName = "Token20B"; const tokenBSymbol = "TOKEN20B";

    const tokenB = await deployToken20(hre, nonce, tokenBName, tokenBSymbol, 18);

    nonce += 1;

    await createBook20(hre, nonce, tokenA, tokenB, tokenAName, tokenBName, 100);
});