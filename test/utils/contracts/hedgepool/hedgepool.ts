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
    previousTick: number,
    nextTick: number,
    amountIn: BigNumber,
    liquidity: BigNumber,
    feeGrowthGlobal: BigNumber,
    feeGrowthGlobalLast: BigNumber,
    secondsGrowthOutside: BigNumber
}

export async function validateSwap(
    signer: SignerWithAddress,
    recipient: string,
    zeroForOne: boolean,
    amountIn: BigNumber,
    sqrtPriceLimitX96: BigNumber,
    balanceInDecrease: BigNumber,
    balanceOutIncrease: BigNumber,
    finalLiquidity: BigNumber,
    finalPrice: BigNumber
) {
    let balanceInBefore; let balanceOutBefore;
    if(zeroForOne){
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
        await hre.props.token0.approve(hre.props.hedgePool.address, amountIn);
    } else {
        balanceInBefore  = await hre.props.token1.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address);
        await hre.props.token1.approve(hre.props.hedgePool.address, amountIn);
    }

    const liquidityBefore           = await hre.props.hedgePool.liquidity();
    const secondsGrowthGlobalBefore = await hre.props.hedgePool.secondsGrowthGlobal();
    const lastBlockNumberBefore     = await hre.props.hedgePool.lastBlockNumber();
    const feeGrowthGlobalBefore     = await hre.props.hedgePool.feeGrowthGlobalIn();
    const latestTickBefore          = await hre.props.hedgePool.latestTick();
    const nearestTickBefore         = await hre.props.hedgePool.nearestTick();
    const priceBefore               = await hre.props.hedgePool.sqrtPrice();

    let txn = await hre.props.hedgePool.swap(
        signer.address,
        true,
        amountIn,
        sqrtPriceLimitX96
    );
    await txn.wait();

    let balanceInAfter; let balanceOutAfter;
    if(zeroForOne){
        balanceInAfter  = await hre.props.token0.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address);
    } else {
        balanceInAfter  = await hre.props.token1.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address);
    }

    expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(balanceInDecrease);
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease);

    const liquidityAfter           = await hre.props.hedgePool.liquidity();
    const secondsGrowthGlobalAfter = await hre.props.hedgePool.secondsGrowthGlobal();
    const lastBlockNumberAfter     = await hre.props.hedgePool.lastBlockNumber();
    const feeGrowthGlobalAfter     = await hre.props.hedgePool.feeGrowthGlobalIn();
    const latestTickAfter          = await hre.props.hedgePool.latestTick();
    const nearestTickAfter         = await hre.props.hedgePool.nearestTick();
    const priceAfter               = await hre.props.hedgePool.sqrtPrice();

    // expect(liquidityAfter).to.be.equal(finalLiquidity);
    // expect(priceAfter).to.be.equal(finalPrice);
    
}
//TODO: approve/mint with signer
export async function validateMint(
    signer: SignerWithAddress,
    recipient: string,
    lowerOld: BigNumber,
    lower: BigNumber,
    upperOld: BigNumber,
    upper: BigNumber,
    amountDesired: BigNumber,
    zeroForOne: boolean,
    balanceInDecrease: BigNumber,
    liquidityIncrease: BigNumber,
    revertMessage: string
) {
    let balanceInBefore; let balanceOutBefore;
    if(zeroForOne){
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
        await hre.props.token0.approve(hre.props.hedgePool.address, amountDesired);
    } else {
        balanceInBefore  = await hre.props.token1.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address);
        await hre.props.token1.approve(hre.props.hedgePool.address, amountDesired);
    }

    const lowerOldTickBefore: Tick = await hre.props.hedgePool.ticks(lowerOld);
    const lowerTickBefore:    Tick = await hre.props.hedgePool.ticks(lower);
    const upperOldTickBefore: Tick = await hre.props.hedgePool.ticks(upperOld);
    const upperTickBefore:    Tick = await hre.props.hedgePool.ticks(upper);
    const positionBefore:     Position = await hre.props.hedgePool.positions(
        recipient,
        lower,
        upper
    );

    if (revertMessage == ""){
        const txn = await hre.props.hedgePool.connect(signer).mint(
            {
              lowerOld: lowerOld,
              lower: lower,
              upperOld: upperOld,
              upper: upper,
              amountDesired: amountDesired,
              zeroForOne: zeroForOne,
              native: false
            }
          );
          await txn.wait();
    } else {
        await expect(hre.props.hedgePool.connect(signer).mint(
            {
              lowerOld: lowerOld,
              lower: lower,
              upperOld: upperOld,
              upper: upper,
              amountDesired: amountDesired,
              zeroForOne: zeroForOne,
              native: false
            }
          )).to.be.revertedWith(revertMessage);
        return;
    }

    let balanceInAfter; let balanceOutAfter;
    if(zeroForOne){
        balanceInAfter  = await hre.props.token0.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address);
    } else {
        balanceInAfter  = await hre.props.token1.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address);
    }

    expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(balanceInDecrease);

    const lowerOldTickAfter: Tick = await hre.props.hedgePool.ticks(lowerOld);
    const lowerTickAfter:    Tick = await hre.props.hedgePool.ticks(lower);
    const upperOldTickAfter: Tick = await hre.props.hedgePool.ticks(upperOld);
    const upperTickAfter:    Tick = await hre.props.hedgePool.ticks(upper);
    const positionAfter:     Position = await hre.props.hedgePool.positions(
        recipient,
        lower,
        upper
    );

    expect(lowerTickAfter.liquidity.sub(lowerOldTickBefore.liquidity)).to.be.equal(liquidityIncrease);
    expect(upperTickAfter.liquidity.sub(upperOldTickBefore.liquidity)).to.be.equal(liquidityIncrease);
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(liquidityIncrease);
}   

export async function validateBurn(
    signer: SignerWithAddress,
    lower: BigNumber,
    upper: BigNumber,
    claim: BigNumber,
    amountDesired: BigNumber,
    zeroForOne: boolean,
    balanceInIncrease: BigNumber,
    balanceOutIncrease: BigNumber,
    revertMessage: string
) {
    let balanceInBefore; let balanceOutBefore;
    if(zeroForOne){
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
    } else {
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
    }

    const lowerTickBefore:    Tick = await hre.props.hedgePool.ticks(lower);
    const upperTickBefore:    Tick = await hre.props.hedgePool.ticks(upper);

    if (revertMessage == ""){
        const txn = await hre.props.hedgePool.connect(signer).burn(
            lower,
            upper,
            claim,
            amountDesired
          );
        await txn.wait();
    } else {
        await expect(hre.props.hedgePool.connect(signer).burn(
            lower,
            upper,
            claim,
            amountDesired
          )).to.be.revertedWith(revertMessage);
        return;
    }


    let balanceInAfter; let balanceOutAfter;
    if(zeroForOne){
        balanceInAfter  = await hre.props.token0.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address);
    } else {
        balanceInAfter  = await hre.props.token0.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address);
    }

    expect(balanceInAfter.sub(balanceInBefore)).to.be.equal(balanceInIncrease);
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease);

    const lowerTickAfter:    Tick = await hre.props.hedgePool.ticks(lower);
    const upperTickAfter:    Tick = await hre.props.hedgePool.ticks(upper);

}