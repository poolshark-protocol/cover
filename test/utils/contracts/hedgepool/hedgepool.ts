import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export async function validateSwap(
    recipient: string,
    signer: SignerWithAddress,
    zeroForOne: boolean,
    amountIn: BigNumber,
    sqrtPriceLimitX96: BigNumber 
) {
    // const inLiquidity = hre.props[amountIn];
    // const sqrtPrice = hre.props[sqrtPriceLimitX96];
    // const address = hre.props[recipient];
}

export async function validateMint(
    lowerOld: BigNumber,
    lower: BigNumber,
    upperOld: BigNumber,
    upper: BigNumber,
    amountDesired: BigNumber,
    zeroForOne: boolean,
    native: boolean
) {
    
}