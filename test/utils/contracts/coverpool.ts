import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export const Q64x96 = BigNumber.from("2").pow(96)
export const BN_ZERO = BigNumber.from("0")
export interface Position {
    liquidity: BigNumber,
    accumEpochLast: number,
    claimPriceLast: BigNumber,
    amountIn: BigNumber,
    amountOut: BigNumber,
}

export interface PoolState {
    liquidity: BigNumber,
    feeGrowthCurrentEpoch: BigNumber,
    price: BigNumber,
    nearestTick: number,
    lastTick: number,
}

export interface TickNode {
    previousTick: number,
    nextTick: number,
    accumEpochLast: number,
}

export interface Tick {
    liquidityDelta: BigNumber,
    liquidityDeltaMinus: BigNumber,
    amountInDelta: BigNumber,
    amountOutDelta: BigNumber,
    amountInDeltaCarryPercent: BigNumber,
    amountOutDeltaCarryPercent: BigNumber,
}

export async function validateSync(
    signer: SignerWithAddress,
    newLatestTick: number
) {
    /// get tick node status before
    
    // const tickNodes = await hre.props.coverPool.tickNodes();
    /// update TWAP
    let txn = await hre.props.rangePoolMock.setTickCumulatives(
        BigNumber.from(newLatestTick.toString()).mul(120),
        BigNumber.from(newLatestTick.toString()).mul(60)
    );
    await txn.wait();

    /// send a "no op" swap to trigger accumulate
    const token1Balance = await hre.props.token1.balanceOf(signer.address);
    await hre.props.token1.approve(hre.props.coverPool.address, token1Balance);
    txn = await hre.props.coverPool.swap(
        signer.address,
        false,
        token1Balance,
        BigNumber.from("4294967296")
    );
    await txn.wait();

    /// check tick status after
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
    finalPrice: BigNumber,
    revertMessage: string
) {
    let balanceInBefore; let balanceOutBefore;
    console.log(sqrtPriceLimitX96.toString())
    if(zeroForOne){
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
        await hre.props.token0.approve(hre.props.coverPool.address, amountIn);
    } else {
        balanceInBefore  = await hre.props.token1.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address);
        await hre.props.token1.approve(hre.props.coverPool.address, amountIn);
    }

    const poolBefore: PoolState       = zeroForOne ? 
                                          await hre.props.coverPool.pool1()
                                        : await hre.props.coverPool.pool0();
    const liquidityBefore             = poolBefore.liquidity;
    const feeGrowthCurrentEpochBefore = poolBefore.feeGrowthCurrentEpoch;
    const nearestTickBefore           = poolBefore.nearestTick;
    const priceBefore                 = poolBefore.price;
    const latestTickBefore            = (await hre.props.coverPool.globalState()).latestTick;

    validateSync(
        hre.props.admin,
        (await hre.props.coverPool.globalState()).latestTick
    );

    // quote pre-swap and validate balance changes match post-swap
    const quote = await hre.props.coverPool.quote(
        zeroForOne,
        amountIn,
        sqrtPriceLimitX96
    );
    const amountInQuoted  = quote[0];
    const amountOutQuoted = quote[1];

    if (revertMessage == ""){
        let txn = await hre.props.coverPool.connect(signer).swap(
            signer.address,
            zeroForOne,
            amountIn,
            sqrtPriceLimitX96
        );
        await txn.wait();
    } else {
        await expect(hre.props.coverPool.connect(signer).swap(
            signer.address,
            zeroForOne,
            amountIn,
            sqrtPriceLimitX96
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
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease);
    expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(amountInQuoted);
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(amountOutQuoted);
    
    const poolAfter: PoolState       = zeroForOne ? 
                                         await hre.props.coverPool.pool1()
                                       : await hre.props.coverPool.pool0();
    const liquidityAfter             = poolAfter.liquidity;
    const feeGrowthCurrentEpochAfter = poolAfter.feeGrowthCurrentEpoch;
    const nearestTickAfter           = poolAfter.nearestTick;
    const priceAfter                 = poolAfter.price;
    const latestTickAfter            = (await hre.props.coverPool.globalState()).latestTick;

    // expect(liquidityAfter).to.be.equal(finalLiquidity);
    // expect(priceAfter).to.be.equal(finalPrice);
    
}

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
    //collect first to recreate positions if necessary
    const collectTxn = await hre.props.coverPool.connect(signer).collect(
        lower,
        upper,
        claim,
        zeroForOne
    );
    await collectTxn.wait();
    let balanceInBefore; let balanceOutBefore;
    if(zeroForOne){
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
        await hre.props.token0.connect(signer).approve(hre.props.coverPool.address, amountDesired);
    } else {
        balanceInBefore  = await hre.props.token1.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address);
        await hre.props.token1.connect(signer).approve(hre.props.coverPool.address, amountDesired);
    }

    let lowerOldTickBefore: Tick;
    let lowerTickBefore:    Tick;
    let upperOldTickBefore: Tick;
    let upperTickBefore:    Tick;
    let positionBefore:     Position;
    if(zeroForOne) {
        lowerOldTickBefore = await hre.props.coverPool.ticks0(lowerOld);
        lowerTickBefore = await hre.props.coverPool.ticks0(lower);
        upperOldTickBefore = await hre.props.coverPool.ticks0(upperOld);
        upperTickBefore = await hre.props.coverPool.ticks0(upper);
        positionBefore = await hre.props.coverPool.positions0(
            recipient,
            lower,
            upper
        );
    } else {
        lowerOldTickBefore = await hre.props.coverPool.ticks1(lowerOld);
        lowerTickBefore = await hre.props.coverPool.ticks1(lower);
        upperOldTickBefore = await hre.props.coverPool.ticks1(upperOld);
        upperTickBefore = await hre.props.coverPool.ticks1(upper);
        positionBefore = await hre.props.coverPool.positions1(
            recipient,
            lower,
            upper
        );
    }
    //console.log('token1 address and balance:', hre.props.token1.address, (await hre.props.token1.balanceOf(signer.address)).toString());
    if (revertMessage == ""){
        const txn = await hre.props.coverPool.connect(signer).mint(
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
        await expect(hre.props.coverPool.connect(signer).mint(
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
    expect(balanceOutBefore).to.be.equal(balanceOutAfter);

    let lowerOldTickAfter: Tick;
    let lowerTickAfter:    Tick;
    let upperOldTickAfter: Tick;
    let upperTickAfter:    Tick;
    let positionAfter:     Position;
    if(zeroForOne) {
        lowerOldTickAfter = await hre.props.coverPool.ticks0(lowerOld);
        lowerTickAfter = await hre.props.coverPool.ticks0(lower);
        upperOldTickAfter = await hre.props.coverPool.ticks0(upperOld);
        upperTickAfter = await hre.props.coverPool.ticks0(upper);
        positionAfter = await hre.props.coverPool.positions0(
            recipient,
            lower,
            upper
        );
    } else {
        lowerOldTickAfter = await hre.props.coverPool.ticks1(lowerOld);
        lowerTickAfter = await hre.props.coverPool.ticks1(lower);
        upperOldTickAfter = await hre.props.coverPool.ticks1(upperOld);
        upperTickAfter = await hre.props.coverPool.ticks1(upper);
        positionAfter = await hre.props.coverPool.positions1(
            recipient,
            lower,
            upper
        );
    }

    //TODO: handle lower and/or upper below TWAP
    //TODO: does this handle negative values okay?
    // console.log('liquidity negative delta:', upperTickAfter.liquidityDelta.toString());
    if (zeroForOne) {
        //liquidity change for lower should be -liquidityAmount
        if(!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(liquidityIncrease);
            expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        } else {
            expect(upperTickAfter.liquidityDelta).to.be.equal(liquidityIncrease);
            expect(upperTickAfter.liquidityDeltaMinus).to.be.equal(BN_ZERO);
        }
        if(!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(BN_ZERO.sub(liquidityIncrease));
            expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(liquidityIncrease);
        } else {
            expect(lowerTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease));
            expect(lowerTickAfter.liquidityDeltaMinus).to.be.equal(liquidityIncrease);
        }
    } else {
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
        balanceInBefore  = await hre.props.token1.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address);
    } else {
        balanceInBefore  = await hre.props.token0.balanceOf(signer.address);
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address);
    }

    let lowerTickBefore:    Tick;
    let upperTickBefore:    Tick;
    let positionBefore:     Position;
    if(zeroForOne) {
        lowerTickBefore = await hre.props.coverPool.ticks0(lower);
        upperTickBefore = await hre.props.coverPool.ticks0(upper);
        positionBefore = await hre.props.coverPool.positions0(
            signer.address,
            lower,
            upper
        );
    } else {
        lowerTickBefore = await hre.props.coverPool.ticks1(lower);
        upperTickBefore = await hre.props.coverPool.ticks1(upper);
        positionBefore = await hre.props.coverPool.positions1(
            signer.address,
            lower,
            upper
        );
    }

    if (revertMessage == ""){
        const burnTxn = await hre.props.coverPool.connect(signer).burn(
            lower,
            upper,
            claim,
            zeroForOne,
            liquidityAmount
          );
        await burnTxn.wait();
        //TODO: expect balances to remain unchanged until collect
        const collectTxn = await hre.props.coverPool.connect(signer).collect(
            lower,
            upper,
            claim,
            zeroForOne
        );
        await collectTxn.wait();
    } else {
        await expect(hre.props.coverPool.connect(signer).burn(
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
        balanceInAfter  = await hre.props.token1.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address);
    } else {
        balanceInAfter  = await hre.props.token0.balanceOf(signer.address);
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address);
    }

    expect(balanceInAfter.sub(balanceInBefore)).to.be.equal(balanceInIncrease);
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease);

    let lowerTickAfter:    Tick;
    let upperTickAfter:    Tick;
    let positionAfter:     Position;
    if(zeroForOne) {
        lowerTickAfter = await hre.props.coverPool.ticks0(lower);
        upperTickAfter = await hre.props.coverPool.ticks0(upper);
        positionAfter = await hre.props.coverPool.positions0(
            signer.address,
            lower,
            upper
        );
    } else {
        lowerTickAfter = await hre.props.coverPool.ticks1(lower);
        upperTickAfter = await hre.props.coverPool.ticks1(upper);
        positionAfter = await hre.props.coverPool.positions1(
            signer.address,
            lower,
            upper
        );
    }

    //dependent on zeroForOne
    if (zeroForOne) {
        if(!upperTickCleared){
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(BN_ZERO.sub(liquidityAmount));
            expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(BN_ZERO);
            expect(upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        }
        if(!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(liquidityAmount);
            expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO.sub(liquidityAmount));
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(BN_ZERO);
            expect(lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)).to.be.equal(BN_ZERO);
        }
    } else {
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
    }
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(BN_ZERO.sub(liquidityAmount));

}