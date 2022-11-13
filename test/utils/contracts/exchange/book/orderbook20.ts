import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export async function validateSwap(
    hedgePoolName: string,
    signer: SignerWithAddress,
    fromTokenName: string,
    destTokenName: string,
    fromAmount: BigNumber,
    destAmount: BigNumber,
    sqrtPriceLimit: BigNumber,
    zeroForOne: boolean
) {

    const orderBook = hre.props[hedgePoolName];
    const fromToken = hre.props[fromTokenName];
    const destToken = hre.props[destTokenName];
    const fromDecimals = await fromToken.decimals();
    const destDecimals = await destToken.decimals();
    const fromMultiplier = ethers.utils.parseUnits("1", fromDecimals);
    const destMultiplier = ethers.utils.parseUnits("1", destDecimals);

    // check before
    // execute swap
    // validate after
}
    
    

    // // validate page keys
    // const pageKey0 = await orderBook.getPageKey(
    //     fromToken.address,
    //     this.token1Amount,
    //     this.token0Amount
    // );

    



//     // should return 1x amount
//     expect(quote[0]).to.be.equal(this.token1Amount);
//     // should return 1x amount
//     expect(quote[1]).to.be.equal(this.token0Amount);

//     expect(await this.token1.balanceOf(this.alice.address))
//     .to.equal(0);

}