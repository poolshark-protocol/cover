import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export const Q64x96 = BigNumber.from("2").pow(96)
export const BN_ZERO = BigNumber.from("0")
export interface Position {
    liquidity: BigNumber,
    feeGrowthGlobalLast: BigNumber,
    claimPriceLast: BigNumber,
    amountIn: BigNumber,
    amountOut: BigNumber
}

export interface Tick {
    previousTick: BigNumber,
    nextTick: BigNumber,
    amountIn: BigNumber,
    amountOut: BigNumber,
    amountInGrowth: BigNumber,
    amountInGrowthLast: BigNumber,
    liquidity: BigNumber,
    feeGrowthGlobal: BigNumber,
    amountInUnfilled: BigNumber,
    secondsGrowthOutside: BigNumber
}

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