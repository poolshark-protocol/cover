import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export const Q64x96 = BigNumber.from("2").pow(96)
export const BN_ZERO = BigNumber.from("0")
export interface Position {
    liquidity: BigNumber,
    feeGrowthGlobalIn: BigNumber,
    claimPriceLast: BigNumber,
    amountIn: BigNumber,
    amountOut: BigNumber
}

export interface PoolState {
    nearestTick: number,
    price: BigNumber,
    liquidity: BigNumber,
    feeGrowthGlobalIn: BigNumber
}

export interface TickNode {
    previousTick: number,
    nextTick: number,
}

export interface Tick {
    liquidityDelta: BigNumber,
    liquidityDeltaMinus: BigNumber,
    feeGrowthGlobalIn: BigNumber,
    amountInDelta: BigNumber,
    amountOutDelta: BigNumber
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


    const pool0Before: PoolState    = await hre.props.hedgePool.pool0();
    const liquidityBefore           = pool0Before.liquidity;
    const feeGrowthGlobalBefore     = pool0Before.feeGrowthGlobalIn;
    const nearestTickBefore         = pool0Before.nearestTick;
    const priceBefore               = pool0Before.price;
    const latestTickBefore          = await hre.props.hedgePool.latestTick();

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

    const pool0After: PoolState    = await hre.props.hedgePool.pool0();
    const liquidityAfter           = pool0After.liquidity;
    const feeGrowthGlobalAfter     = pool0After.feeGrowthGlobalIn;
    const nearestTickAfter         = pool0After.nearestTick;
    const priceAfter               = pool0After.price;
    const latestTickAfter          = await hre.props.hedgePool.latestTick();

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
    claim: BigNumber,
    amountDesired: BigNumber,
    zeroForOne: boolean,
    balanceInDecrease: BigNumber,
    liquidityIncrease: BigNumber,
    upperTickCleared: boolean,
    lowerTickCleared: boolean,
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

    const lowerOldTickBefore: Tick = await hre.props.hedgePool.ticks1(lowerOld);
    const lowerTickBefore:    Tick = await hre.props.hedgePool.ticks1(lower);
    const upperOldTickBefore: Tick = await hre.props.hedgePool.ticks1(upperOld);
    const upperTickBefore:    Tick = await hre.props.hedgePool.ticks1(upper);
    const positionBefore:     Position = await hre.props.hedgePool.positions1(
        recipient,
        lower,
        upper
    );
        console.log('token1 address and balance:', hre.props.token1.address, (await hre.props.token1.balanceOf(signer.address)).toString());
    if (revertMessage == ""){
        const txn = await hre.props.hedgePool.connect(signer).mint(
            lowerOld,
            lower,
            upperOld,
            upper,
            claim,
            amountDesired,
            zeroForOne
          );
          await txn.wait();
    } else {
        await expect(hre.props.hedgePool.connect(signer).mint(
            lowerOld,
            lower,
            upperOld,
            upper,
            claim,
            amountDesired,
            zeroForOne
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

    const lowerOldTickAfter: Tick = await hre.props.hedgePool.ticks1(lowerOld);
    const lowerTickAfter:    Tick = await hre.props.hedgePool.ticks1(lower);
    const upperOldTickAfter: Tick = await hre.props.hedgePool.ticks1(upperOld);
    const upperTickAfter:    Tick = await hre.props.hedgePool.ticks1(upper);
    const positionAfter:     Position = await hre.props.hedgePool.positions1(
        recipient,
        lower,
        upper
    );
    //TODO: handle lower and/or upper below TWAP
    //TODO: does this handle negative values okay?
    // console.log('liquidity negative delta:', upperTickAfter.liquidityDelta.toString());
    if(!lowerTickCleared) {
        expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(liquidityIncrease);
        expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
    } else {
        expect(lowerTickAfter.liquidityDelta).to.be.equal(liquidityIncrease);
        expect(lowerTickAfter.liquidityDeltaMinus).to.be.equal(BN_ZERO);
    }
    if(!upperTickCleared) {
        expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(BN_ZERO.sub(liquidityIncrease));
        expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(liquidityIncrease);
    } else {
        expect(upperTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease));
        expect(upperTickAfter.liquidityDeltaMinus).to.be.equal(liquidityIncrease);
    }
    
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(liquidityIncrease);
}   

export async function validateBurn(
    signer: SignerWithAddress,
    lower: BigNumber,
    upper: BigNumber,
    claim: BigNumber,
    liquidityAmount: BigNumber,
    zeroForOne: boolean,
    balanceInIncrease: BigNumber,
    balanceOutIncrease: BigNumber,
    lowerTickCleared: boolean,
    upperTickCleared: boolean,
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

    const positionBefore: Position = await hre.props.hedgePool.positions1(
        signer.address,
        lower,
        upper
    );
    const lowerTickBefore:    Tick = await hre.props.hedgePool.ticks1(lower);
    const upperTickBefore:    Tick = await hre.props.hedgePool.ticks1(upper);

    if (revertMessage == ""){
        const txn = await hre.props.hedgePool.connect(signer).burn(
            lower,
            upper,
            claim,
            zeroForOne,
            liquidityAmount
          );
        await txn.wait();
    } else {
        await expect(hre.props.hedgePool.connect(signer).burn(
            lower,
            upper,
            claim,
            zeroForOne,
            liquidityAmount
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

    const positionAfter: Position = await hre.props.hedgePool.positions1(
        signer.address,
        lower,
        upper
    );
    const lowerTickAfter:    Tick = await hre.props.hedgePool.ticks1(lower);
    const upperTickAfter:    Tick = await hre.props.hedgePool.ticks1(upper);

    //dependent on zeroForOne
    if (!zeroForOne) {
        //liquidity change for lower should be -liquidityAmount
        if(!lowerTickCleared){
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(BN_ZERO.sub(liquidityAmount));
            expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(BN_ZERO);
            expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        }
        if(!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(liquidityAmount);
            expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO.sub(liquidityAmount));
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(BN_ZERO);
            expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        }


    } else {
        
    }
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(BN_ZERO.sub(liquidityAmount));

}