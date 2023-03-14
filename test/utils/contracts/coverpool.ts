import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { network } from 'hardhat';

export const Q64x96 = BigNumber.from('2').pow(96)
export const BN_ZERO = BigNumber.from('0')
export interface Position {
    liquidity: BigNumber
    accumEpochLast: number
    claimPriceLast: BigNumber
    amountIn: BigNumber
    amountOut: BigNumber
}

export interface PoolState {
    liquidity: BigNumber
    amountInDelta: BigNumber
    price: BigNumber
}

export interface TickNode {
    previousTick: number
    nextTick: number
    accumEpochLast: number
    liquidityDeltaMinus: BigNumber
}

export interface Tick {
    liquidityDelta: BigNumber
    liquidityDeltaMinus: BigNumber
    amountInDeltaMaxStashed: BigNumber
    amountOutDeltaMaxStashed: BigNumber
    deltas: Deltas
}

export interface Deltas {
    amountInDelta: BigNumber
    amountInDeltaMax: BigNumber
    amountOutDelta: BigNumber
    amountOutDeltaMax: BigNumber
}

export interface ValidateMintParams {
    signer: SignerWithAddress
    recipient: string
    lowerOld: string
    lower: string
    upperOld: string
    upper: string
    claim: string
    amount: BigNumber
    zeroForOne: boolean
    balanceInDecrease: BigNumber
    liquidityIncrease: BigNumber
    upperTickCleared: boolean
    lowerTickCleared: boolean
    revertMessage: string
    collectRevertMessage?: string
    expectedLower?: string
    expectedUpper?: string
}

export interface ValidateSwapParams {
    signer: SignerWithAddress
    recipient: string
    zeroForOne: boolean
    amountIn: BigNumber
    sqrtPriceLimitX96: BigNumber
    balanceInDecrease: BigNumber
    balanceOutIncrease: BigNumber
    revertMessage: string
}

export interface ValidateBurnParams {
    signer: SignerWithAddress
    lower: string
    upper: string
    claim: string
    liquidityAmount: BigNumber
    zeroForOne: boolean
    balanceInIncrease: BigNumber
    balanceOutIncrease: BigNumber
    lowerTickCleared: boolean
    upperTickCleared: boolean
    revertMessage: string
}

export async function validateSync(signer: SignerWithAddress, newLatestTick: string) {
    /// get tick node status before

    // const tickNodes = await hre.props.coverPool.tickNodes();
    /// update TWAP
    let txn = await hre.props.rangePoolMock.setTickCumulatives(
        BigNumber.from(newLatestTick).mul(120),
        BigNumber.from(newLatestTick).mul(60)
    )
    await txn.wait()

    /// send a "no op" swap to trigger accumulate
    const token1Balance = await hre.props.token1.balanceOf(signer.address)
    await hre.props.token1.approve(hre.props.coverPool.address, token1Balance)

    txn = await hre.props.coverPool.swap(
        signer.address,
        true,
        BigNumber.from('0'),
        BigNumber.from('4295128739')
    )
    await txn.wait()

    /// check tick status after
}

export async function validateSwap(params: ValidateSwapParams) {
    const signer = params.signer
    const recipient = params.recipient
    const zeroForOne = params.zeroForOne
    const amountIn = params.amountIn
    const sqrtPriceLimitX96 = params.sqrtPriceLimitX96
    const balanceInDecrease = params.balanceInDecrease
    const balanceOutIncrease = params.balanceOutIncrease
    const revertMessage = params.revertMessage

    let balanceInBefore
    let balanceOutBefore
    if (zeroForOne) {
        balanceInBefore = await hre.props.token0.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address)
        await hre.props.token0.approve(hre.props.coverPool.address, amountIn)
    } else {
        balanceInBefore = await hre.props.token1.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address)
        await hre.props.token1.approve(hre.props.coverPool.address, amountIn)
    }

    const poolBefore: PoolState = zeroForOne
        ? await hre.props.coverPool.pool1()
        : await hre.props.coverPool.pool0()
    const liquidityBefore = poolBefore.liquidity
    const amountInDeltaBefore = poolBefore.amountInDelta
    const priceBefore = poolBefore.price
    const latestTickBefore = (await hre.props.coverPool.globalState()).latestTick

    validateSync(hre.props.admin, (await hre.props.coverPool.globalState()).latestTick.toString())

    // quote pre-swap and validate balance changes match post-swap
    const quote = await hre.props.coverPool.quote(zeroForOne, amountIn, sqrtPriceLimitX96)

    const amountInQuoted = quote[0]
    const amountOutQuoted = quote[1]

    // await network.provider.send('evm_setAutomine', [false]);

    if (revertMessage == '') {
        let txn = await hre.props.coverPool
            .connect(signer)
            .swap(signer.address, zeroForOne, amountIn, sqrtPriceLimitX96)
        await txn.wait()
    } else {
        await expect(
            hre.props.coverPool
                .connect(signer)
                .swap(signer.address, zeroForOne, amountIn, sqrtPriceLimitX96)
        ).to.be.revertedWith(revertMessage)
        return
    }

    let balanceInAfter
    let balanceOutAfter
    if (zeroForOne) {
        balanceInAfter = await hre.props.token0.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address)
    } else {
        balanceInAfter = await hre.props.token1.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address)
    }

    expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(balanceInDecrease)
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease)
    //TODO: validate quote amount
    // expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(amountInQuoted)
    // expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(amountOutQuoted)

    const poolAfter: PoolState = zeroForOne
        ? await hre.props.coverPool.pool1()
        : await hre.props.coverPool.pool0()
    const liquidityAfter = poolAfter.liquidity
    const amountInDeltaAfter = poolAfter.amountInDelta
    const priceAfter = poolAfter.price
    const latestTickAfter = (await hre.props.coverPool.globalState()).latestTick

    // expect(liquidityAfter).to.be.equal(finalLiquidity);
    // expect(priceAfter).to.be.equal(finalPrice);
}

export async function validateMint(params: ValidateMintParams) {
    const signer = params.signer
    const recipient = params.recipient
    const lowerOld = BigNumber.from(params.lowerOld)
    const lower = BigNumber.from(params.lower)
    const upper = BigNumber.from(params.upper)
    const upperOld = BigNumber.from(params.upperOld)
    const claim = BigNumber.from(params.claim)
    const amountDesired = params.amount
    const zeroForOne = params.zeroForOne
    const balanceInDecrease = params.balanceInDecrease
    const liquidityIncrease = params.liquidityIncrease
    const upperTickCleared = params.upperTickCleared
    const lowerTickCleared = params.lowerTickCleared
    const revertMessage = params.revertMessage
    const collectRevertMessage = params.collectRevertMessage
    const expectedUpper = params.expectedUpper ? BigNumber.from(params.expectedUpper) : null
    const expectedLower = params.expectedLower ? BigNumber.from(params.expectedLower) : null

    //collect first to recreate positions if necessary
    if (!collectRevertMessage) {
        const txn = await hre.props.coverPool
            .connect(params.signer)
            .collect(lower, claim, upper, zeroForOne)
        await txn.wait()
    } else {
        await expect(
            hre.props.coverPool.connect(params.signer).collect(lower, claim, upper, zeroForOne)
        ).to.be.revertedWith(collectRevertMessage)
    }
    let balanceInBefore
    let balanceOutBefore
    if (zeroForOne) {
        balanceInBefore = await hre.props.token0.balanceOf(params.signer.address)
        balanceOutBefore = await hre.props.token1.balanceOf(params.signer.address)
        await hre.props.token0
            .connect(params.signer)
            .approve(hre.props.coverPool.address, amountDesired)
    } else {
        balanceInBefore = await hre.props.token1.balanceOf(params.signer.address)
        balanceOutBefore = await hre.props.token0.balanceOf(params.signer.address)
        await hre.props.token1
            .connect(params.signer)
            .approve(hre.props.coverPool.address, amountDesired)
    }

    let lowerTickBefore: Tick
    let upperTickBefore: Tick
    let positionBefore: Position
    if (zeroForOne) {
        lowerTickBefore = await hre.props.coverPool.ticks0(lower)
        upperTickBefore = await hre.props.coverPool.ticks0(expectedUpper ? expectedUpper : upper)
        positionBefore = await hre.props.coverPool.positions0(
            recipient,
            lower,
            expectedUpper ? expectedUpper : upper
        )
    } else {
        lowerTickBefore = await hre.props.coverPool.ticks1(expectedLower ? expectedLower : lower)
        upperTickBefore = await hre.props.coverPool.ticks1(upper)
        positionBefore = await hre.props.coverPool.positions1(
            recipient,
            expectedLower ? expectedLower : lower,
            upper
        )
    }
    if (revertMessage == '') {
        const txn = await hre.props.coverPool
            .connect(params.signer)
            .mint({
                recipient: params.signer.address,
                lowerOld: lowerOld, 
                lower: lower,
                claim: claim,
                upper: upper,
                upperOld: upperOld,
                amount: amountDesired,
                zeroForOne: zeroForOne
              })
        await txn.wait()
    } else {
        await expect(
            hre.props.coverPool
                .connect(params.signer)
                .mint({
                    recipient: params.signer.address,
                    lowerOld: lowerOld, 
                    lower: lower,
                    claim: claim,
                    upper: upper,
                    upperOld: upperOld,
                    amount: amountDesired,
                    zeroForOne: zeroForOne
                })
        ).to.be.revertedWith(revertMessage)
        return
    }

    let balanceInAfter
    let balanceOutAfter
    if (zeroForOne) {
        balanceInAfter = await hre.props.token0.balanceOf(params.signer.address)
        balanceOutAfter = await hre.props.token1.balanceOf(params.signer.address)
    } else {
        balanceInAfter = await hre.props.token1.balanceOf(params.signer.address)
        balanceOutAfter = await hre.props.token0.balanceOf(params.signer.address)
    }

    expect(balanceInBefore.sub(balanceInAfter)).to.be.equal(balanceInDecrease)
    expect(balanceOutBefore).to.be.equal(balanceOutAfter)

    let lowerTickAfter: Tick
    let upperTickAfter: Tick
    let positionAfter: Position
    if (zeroForOne) {
        lowerTickAfter = await hre.props.coverPool.ticks0(lower)
        upperTickAfter = await hre.props.coverPool.ticks0(expectedUpper ? expectedUpper : upper)
        positionAfter = await hre.props.coverPool.positions0(
            recipient,
            lower,
            expectedUpper ? expectedUpper : upper
        )
    } else {
        lowerTickAfter = await hre.props.coverPool.ticks1(expectedLower ? expectedLower : lower)
        upperTickAfter = await hre.props.coverPool.ticks1(upper)
        positionAfter = await hre.props.coverPool.positions1(
            recipient,
            expectedLower ? expectedLower : lower,
            upper
        )
    }

    //TODO: handle lower and/or upper below TWAP
    //TODO: does this handle negative values okay?
    if (zeroForOne) {
        //liquidity change for lower should be -liquidityAmount
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                liquidityIncrease
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        } else {
            expect(upperTickAfter.liquidityDelta).to.be.equal(liquidityIncrease)
            expect(upperTickAfter.liquidityDeltaMinus).to.be.equal(BN_ZERO)
        }
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityIncrease)
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(liquidityIncrease)
        } else {
            expect(lowerTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease))
            expect(lowerTickAfter.liquidityDeltaMinus).to.be.equal(liquidityIncrease)
        }
    } else {
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                liquidityIncrease
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        } else {
            expect(lowerTickAfter.liquidityDelta).to.be.equal(liquidityIncrease)
            expect(lowerTickAfter.liquidityDeltaMinus).to.be.equal(BN_ZERO)
        }
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityIncrease)
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(liquidityIncrease)
        } else {
            expect(upperTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease))
            expect(upperTickAfter.liquidityDeltaMinus).to.be.equal(liquidityIncrease)
        }
    }
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(liquidityIncrease)
}

export async function validateBurn(params: ValidateBurnParams) {
    //TODO: check liquidityDeltaMinus on lower : upper tick
    const signer = params.signer
    const lower = BigNumber.from(params.lower)
    const upper = BigNumber.from(params.upper)
    const claim = BigNumber.from(params.claim)
    const liquidityAmount = params.liquidityAmount
    const zeroForOne = params.zeroForOne
    const balanceInIncrease = params.balanceInIncrease
    const balanceOutIncrease = params.balanceOutIncrease
    const upperTickCleared = params.upperTickCleared
    const lowerTickCleared = params.lowerTickCleared
    const revertMessage = params.revertMessage

    let balanceInBefore
    let balanceOutBefore
    if (zeroForOne) {
        balanceInBefore = await hre.props.token1.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address)
    } else {
        balanceInBefore = await hre.props.token0.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address)
    }

    // console.log('pool balance before')
    // console.log((await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
    // console.log((await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())

    let lowerTickBefore: Tick
    let upperTickBefore: Tick
    let positionBefore: Position
    if (zeroForOne) {
        lowerTickBefore = await hre.props.coverPool.ticks0(lower)
        upperTickBefore = await hre.props.coverPool.ticks0(upper)
        positionBefore = await hre.props.coverPool.positions0(signer.address, lower, upper)
    } else {
        lowerTickBefore = await hre.props.coverPool.ticks1(lower)
        upperTickBefore = await hre.props.coverPool.ticks1(upper)
        positionBefore = await hre.props.coverPool.positions1(signer.address, lower, upper)
    }

    if (revertMessage == '') {
        const burnTxn = await hre.props.coverPool
            .connect(signer)
            .burn(lower, claim, upper, zeroForOne, liquidityAmount)
        await burnTxn.wait()
        //TODO: expect balances to remain unchanged until collect
        const collectTxn = await hre.props.coverPool
            .connect(signer)
            .collect(lower, claim, upper, zeroForOne)
        await collectTxn.wait()
    } else {
        await expect(
            hre.props.coverPool
                .connect(signer)
                .burn(lower, claim, upper, zeroForOne, liquidityAmount)
        ).to.be.revertedWith(revertMessage)
        return
    }
    // console.log('-60 tick after:', (await hre.props.coverPool.ticks0("-60")).toString())
    let balanceInAfter
    let balanceOutAfter
    if (zeroForOne) {
        balanceInAfter = await hre.props.token1.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address)
    } else {
        balanceInAfter = await hre.props.token0.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address)
    }
    // console.log('pool balance after')
    // console.log((await hre.props.token0.balanceOf(hre.props.coverPool.address)).toString())
    // console.log((await hre.props.token1.balanceOf(hre.props.coverPool.address)).toString())

    expect(balanceInAfter.sub(balanceInBefore)).to.be.equal(balanceInIncrease)
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease)

    let lowerTickAfter: Tick
    let upperTickAfter: Tick
    let positionAfter: Position
    //TODO: implement expected lower/upper?
    if (zeroForOne) {
        lowerTickAfter = await hre.props.coverPool.ticks0(lower)
        upperTickAfter = await hre.props.coverPool.ticks0(upper)
        positionAfter = await hre.props.coverPool.positions0(signer.address, lower, upper)
    } else {
        lowerTickAfter = await hre.props.coverPool.ticks1(lower)
        upperTickAfter = await hre.props.coverPool.ticks1(upper)
        positionAfter = await hre.props.coverPool.positions1(signer.address, lower, upper)
    }
    //dependent on zeroForOne
    if (zeroForOne) {
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityAmount)
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        }
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                liquidityAmount
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO.sub(liquidityAmount))
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        }
    } else {
        //liquidity change for lower should be -liquidityAmount
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityAmount)
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
            expect(
                lowerTickAfter.liquidityDeltaMinus.sub(lowerTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        }
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                liquidityAmount
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO.sub(liquidityAmount))
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
            expect(
                upperTickAfter.liquidityDeltaMinus.sub(upperTickBefore.liquidityDeltaMinus)
            ).to.be.equal(BN_ZERO)
        }
    }
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(
        BN_ZERO.sub(liquidityAmount)
    )
}
