import { task } from "hardhat/config";
import { deployOrderBookRouter20 } from "../../../deploy/deploy20";
import { getWalletAddress, getNonce } from "../../../utils";

task("deploy-router-20", "deploy router for OrderBook20")
.setAction(async (args, hre) => {
  if(process.env.PRIVATE_KEY == undefined){
    return;
  }
  const accountAddress = await getWalletAddress(hre, process.env.PRIVATE_KEY);
  let nonce = await getNonce(hre, accountAddress);

  await deployOrderBookRouter20(hre, nonce);
});

// export async function limitOrder20(
//     user: SignerWithAddress,
//     fromToken: ERC20, 
//     destToken: ERC20,
//     fee: number, 
//     fromAmount: number, 
//     destAmount: number,
//     orderBookRouter20: OrderBookRouter20
//   ) {
//     let fromTokenContract: ERC20 = await ethers.getContractAt("ERC20", fromToken.address);

//     const preBal = await fromTokenContract.balanceOf(user.address)
//     await fundUser(fromToken, user, fromAmount);

//     await fromTokenContract
//       .connect(user)
//       .approve(orderBookRouter20.address, fromAmount);

//     const ret = await (await orderBookRouter20.connect(user).limitOrder(
//         fromAmount,
//         destAmount,
//         fromToken.address,
//         destToken.address,
//         fee,
//         false,
//         false
//       )).wait();

//     expect(await fromTokenContract.balanceOf(user.address))
//       .to.equal(preBal);

//     return ret
//   }

//   export async function fundUser(token, userToFund, amount, needsEth = false) {
//     let whaleAddress = token.whale;

//     await ethers.provider.send("hardhat_impersonateAccount", [
//       whaleAddress,
//     ]);
//     const impersonatedAccount = await ethers.provider.getSigner(
//       whaleAddress
//     );

//     if(token.symbol == "ETH") {
//       // send ethers
//       await impersonatedAccount.sendTransaction({
//         to: userToFund.address,
//         value: amount
//       });
//     } else {
//       // send ERC20 tokens
//       const tokenContract = await ethers.getContractAt(ERC20_ABI, token.address);
//       await tokenContract
//         .connect(impersonatedAccount)
//         .transfer(userToFund.address, amount);
//     }

//     await ethers.provider.send("hardhat_stopImpersonatingAccount", [
//       whaleAddress,
//     ]);

//     if (needsEth) {
//       whaleAddress = TOKENS.eth.whale;

//       await ethers.provider.send("hardhat_impersonateAccount", [
//         whaleAddress,
//       ]);
//       const ETHimpersonatedAccount = await ethers.provider.getSigner(
//         whaleAddress
//       );

//       await ETHimpersonatedAccount.sendTransaction({
//         to: userToFund.address,
//         // send 100 gwei
//         value: 100_000_000_000_000
//       });

//       await ethers.provider.send("hardhat_stopImpersonatingAccount", [
//         whaleAddress,
//       ]);
//     }
//   }