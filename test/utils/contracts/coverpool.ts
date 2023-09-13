import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { sign } from 'crypto';
import { BigNumber } from 'ethers'
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

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

export interface VolatilityTier {
    minAmountPerAuction: BigNumber // based on 18 decimals and then converted based on token decimals
    auctionLength: number
    blockTime: number  // average block time where 1e3 is 1 second
    syncFee: number
    fillFee: number
    minPositionWidth: number
    minAmountLowerPriced: boolean
}

export interface CoverImmutables {
    source: string
    bounds: PriceBounds
    owner: string
    token0: string
    token1: string
    poolImpl: string
    inputPool: string
    minAmountPerAuction: BigNumber
    genesisTime: number
    minPositionWidth: number
    tickSpread: number
    twapLength: number
    auctionLength: number
    blockTime: number
    token0Decimals: number
    token1Decimals: number
    minAmountLowerPriced: boolean
}

export interface PriceBounds {
    min: BigNumber
    max: BigNumber
}

export interface CoverPoolParams {
    poolType: any // bytes
    tokenIn: string
    tokenOut: string
    feeTier: number
    tickSpread: number
    twapLength: number
}

export interface Tick {
    liquidityDelta: BigNumber
    amountInDeltaMaxStashed: BigNumber
    amountOutDeltaMaxStashed: BigNumber
    deltas0: Deltas
    deltas1: Deltas
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
    lower: string
    upper: string
    amount: BigNumber
    zeroForOne: boolean
    balanceInDecrease: BigNumber
    balanceOutIncrease?: BigNumber
    liquidityIncrease: BigNumber
    positionLiquidityChange?: BigNumber
    upperTickCleared: boolean
    lowerTickCleared: boolean
    revertMessage: string
    collectRevertMessage?: string
    expectedLower?: string
    expectedUpper?: string
    positionId?: number
}

export interface ValidateSwapParams {
    signer: SignerWithAddress
    recipient: string
    zeroForOne: boolean
    amountIn: BigNumber
    priceLimit: BigNumber
    balanceInDecrease: BigNumber
    balanceOutIncrease: BigNumber
    revertMessage: string
    syncRevertMessage?: string
    splitInto?: number
    exactIn?: boolean
}

export interface ValidateBurnParams {
    signer: SignerWithAddress
    lower: string
    upper: string
    claim: string
    positionId: number
    liquidityAmount?: BigNumber
    liquidityPercent?: BigNumber
    zeroForOne: boolean
    balanceInIncrease: BigNumber
    balanceOutIncrease: BigNumber
    lowerTickCleared: boolean
    upperTickCleared: boolean
    expectedLower?: string
    expectedUpper?: string
    compareSnapshot?: boolean
    positionLiquidityChange?: BigNumber,
    revertMessage: string
}

export async function getLatestTick(print: boolean = false): Promise<number> {
    const latestTick = (await hre.props.coverPool.globalState()).latestTick
    if (print) {
        console.log('latest tick:', latestTick)
    }
    return latestTick
}

export async function getLiquidity(isPool0: boolean, print: boolean = false): Promise<BigNumber> {
    let liquidity: BigNumber = isPool0 ? (await hre.props.coverPool.pool0()).liquidity
                                       : (await hre.props.coverPool.pool1()).liquidity;
    if (print) {
        console.log('pool liquidity:', liquidity.toString())
    }
    return liquidity
}

export async function getPrice(isPool0: boolean, print: boolean = false): Promise<BigNumber> {
    let price: BigNumber = isPool0 ? (await hre.props.coverPool.pool0()).price
                                   : (await hre.props.coverPool.pool1()).price;
    if (print) {
        console.log('price:', price.toString())
    }
    return price
}

export async function getTick(isPool0: boolean, tickIndex: number, print: boolean = false): Promise<Tick> {
    let tick: Tick = isPool0 ? (await hre.props.coverPool.ticks(tickIndex))
                             : (await hre.props.coverPool.ticks(tickIndex));
    if (print) {
        console.log(tickIndex,'tick:', tick.toString())
    }
    return tick
}

export async function getPositionLiquidity(isPool0: boolean, positionId: number, print: boolean = false): Promise<BigNumber> {
    let positionLiquidity: BigNumber = isPool0 ? (await hre.props.coverPool.positions0(positionId)).liquidity
                                               : (await hre.props.coverPool.positions1(positionId)).liquidity;
    if (print) {
        console.log('position liquidity:', positionLiquidity.toString())
    }
    return positionLiquidity
}

export async function validateSync(newLatestTick: number, autoSync: boolean = true, revertMessage?: string, signer: SignerWithAddress = hre.props.alice) {
    /// get tick node status before

    const globalState = (await hre.props.coverPool.globalState())
    const oldLatestTick: number = globalState.latestTick
    const tickSpread: number = await hre.props.coverPool.tickSpread()

    if (newLatestTick != oldLatestTick && hre.network.name == 'hardhat') {
        // mine until end of auction
        const auctionLength: number = Math.trunc(await hre.props.coverPool.auctionLength()
                                        * Math.abs(newLatestTick - oldLatestTick) / tickSpread);
        await mine(auctionLength)
    }
    let txn = await hre.props.uniswapV3PoolMock.connect(signer).setTickCumulatives(
        newLatestTick * 10,
        newLatestTick * 8,
        newLatestTick * 7,
        newLatestTick * 5
    )
    await txn.wait();

    /// send a "no op" swap to trigger accumulate
    const token1Balance = await hre.props.token1.balanceOf(signer.address)
    await hre.props.token1.connect(signer).approve(hre.props.coverPool.address, token1Balance)

    if (autoSync) {
        if (!revertMessage || revertMessage == '') {
            txn = await hre.props.poolRouter
                    .connect(signer)
                    .multiCall(
                    [hre.props.coverPool.address], 
                    [{
                        to: signer.address,
                        priceLimit: BigNumber.from('4297706460'),
                        amount: BN_ZERO,
                        exactIn: true,
                        zeroForOne: true,
                        callbackData: ethers.utils.formatBytes32String('')
                    }], {gasLimit: 3000000})
            await txn.wait()
        } else {
            await expect(
                hre.props.poolRouter
                .connect(signer)
                .multiCall(
                [hre.props.coverPool.address],  
                [{
                    to: signer.address,
                    priceLimit: BigNumber.from('4297706460'),
                    amount: BN_ZERO,
                    exactIn: true,
                    zeroForOne: true,
                    callbackData: ethers.utils.formatBytes32String('')
                }], {gasLimit: 3000000})
            ).to.be.revertedWith(revertMessage)
            return
        }
        await txn.wait()
    }
    /// check tick status after
}

export async function validateSwap(params: ValidateSwapParams) {
    const signer = params.signer
    const recipient = params.recipient
    const zeroForOne = params.zeroForOne
    const amountIn = params.amountIn
    const priceLimit = params.priceLimit
    const balanceInDecrease = params.balanceInDecrease
    const balanceOutIncrease = params.balanceOutIncrease
    const revertMessage = params.revertMessage
    const syncRevertMessage = params.syncRevertMessage
    const splitInto = params.splitInto && params.splitInto > 1 ? params.splitInto : 1
    const exactIn = params.exactIn ?? true
    let balanceInBefore
    let balanceOutBefore
    if (zeroForOne) {
        balanceInBefore = await hre.props.token0.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address)
        await hre.props.token0.approve(hre.props.poolRouter.address, amountIn)
    } else {
        balanceInBefore = await hre.props.token1.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address)
        await hre.props.token1.approve(hre.props.poolRouter.address, amountIn)
    }

    const poolBefore: PoolState = zeroForOne
        ? await hre.props.coverPool.pool1()
        : await hre.props.coverPool.pool0()
    const liquidityBefore = poolBefore.liquidity
    const amountInDeltaBefore = poolBefore.amountInDelta
    const priceBefore = poolBefore.price
    const latestTickBefore = (await hre.props.coverPool.globalState()).latestTick

    // quote pre-swap and validate balance changes match post-swap
    const quote = await hre.props.coverPool.quote({
        priceLimit: priceLimit,
        amount: amountIn,
        exactIn: true,
        zeroForOne: zeroForOne
    })

    const amountInQuoted = quote[0]
    const amountOutQuoted = quote[1]

    // await network.provider.send('evm_setAutomine', [false]);

    if (revertMessage == '') {
        if (splitInto > 1) await ethers.provider.send("evm_setAutomine", [false]);
        for (let i = 0; i < splitInto; i++) {
            // console.log('SWAP CALL')
            let txn = await hre.props.poolRouter
            .connect(signer)
            .multiCall(
            [hre.props.coverPool.address],  
            [{
              to: signer.address,
              zeroForOne: zeroForOne,
              amount: amountIn.div(splitInto),
              priceLimit: priceLimit,
              exactIn: exactIn,
              callbackData: ethers.utils.formatBytes32String('')
            }], {gasLimit: 3000000})
            if (splitInto == 1) await txn.wait()
        }
        if (splitInto > 1){
            await ethers.provider.send('evm_mine')
            await ethers.provider.send("evm_setAutomine", [true])
        } 
    } else {
        await expect(
            hre.props.poolRouter
            .connect(signer)
            .multiCall(
            [hre.props.coverPool.address],  
            [{
              to: signer.address,
              zeroForOne: zeroForOne,
              amount: amountIn.div(splitInto),
              priceLimit: priceLimit,
              exactIn: exactIn,
              callbackData: ethers.utils.formatBytes32String('')
            }], {gasLimit: 3000000})
        ).to.be.revertedWith(revertMessage)
        return
    }
    //amountInDelta in the pool should have increased by the balance change
    (await hre.props.coverPool.pool0()).amountInDelta.toString()

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
    /// @dev - quoted amount changes because swap happens on a new block with a new timestamp
    // we would need to use the router to do a quote and then a swap in the same block
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

export async function validateMint(params: ValidateMintParams): Promise<number> {
    const signer = params.signer
    const recipient = params.recipient
    const lower = BigNumber.from(params.lower)
    const upper = BigNumber.from(params.upper)
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
    const balanceOutIncrease = params.balanceOutIncrease ? BigNumber.from(params.balanceOutIncrease) : 0
    const positionId = params.positionId ? params.positionId : 0
    let expectedPositionId = (params.positionId && params.positionId > 0) ? params.positionId 
                                                                            : (await hre.props.coverPool.globalState()).positionIdNext
    if (expectedPositionId == 0) expectedPositionId = 1

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
        lowerTickBefore = await hre.props.coverPool.ticks(lower)
        upperTickBefore = await hre.props.coverPool.ticks(expectedUpper ? expectedUpper : upper)
        positionBefore  = await hre.props.coverPool.positions0(
            expectedPositionId
        )
    } else {
        lowerTickBefore = await hre.props.coverPool.ticks(expectedLower ? expectedLower : lower)
        upperTickBefore = await hre.props.coverPool.ticks(upper)
        positionBefore  = await hre.props.coverPool.positions1(
            expectedPositionId
        )
    }

    if (revertMessage == '') {
        // console.log('MINT CALL')
        const txn = await hre.props.coverPool
            .connect(params.signer)
            .mint({
                to: recipient,
                amount: amountDesired,
                positionId: positionId,
                lower: lower,
                upper: upper,
                zeroForOne: zeroForOne
            })
        await txn.wait()
    } else {
        await expect(
            hre.props.coverPool
                .connect(params.signer)
                .mint({
                    to: params.signer.address,
                    positionId: positionId,
                    lower: lower,
                    upper: upper,
                    amount: amountDesired,
                    zeroForOne: zeroForOne
                })
        ).to.be.revertedWith(revertMessage)
        return expectedPositionId
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
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease)

    let lowerTickAfter: Tick
    let upperTickAfter: Tick
    let positionAfter: Position
    if (zeroForOne) {
        lowerTickAfter = await hre.props.coverPool.ticks(lower)
        upperTickAfter = await hre.props.coverPool.ticks(expectedUpper ? expectedUpper : upper)
        positionAfter = await hre.props.coverPool.positions0(
            expectedPositionId
        )
    } else {
        lowerTickAfter = await hre.props.coverPool.ticks(expectedLower ? expectedLower : lower)
        upperTickAfter = await hre.props.coverPool.ticks(upper)
        positionAfter = await hre.props.coverPool.positions1(
            expectedPositionId
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
        } else {
            expect(upperTickAfter.liquidityDelta).to.be.equal(liquidityIncrease)
        }
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityIncrease)
            )
        } else {
            expect(lowerTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease))
        }
    } else {
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                liquidityIncrease
            )
        } else {
            expect(lowerTickAfter.liquidityDelta).to.be.equal(liquidityIncrease)
        }
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityIncrease)
            )
        } else {
            expect(upperTickAfter.liquidityDelta).to.be.equal(BN_ZERO.sub(liquidityIncrease))
        }
    }
    const positionLiquidityChange = params.positionLiquidityChange ? params.positionLiquidityChange : liquidityIncrease
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(positionLiquidityChange)

    return expectedPositionId
}

export async function validateBurn(params: ValidateBurnParams) {

    const signer = params.signer
    const lower = BigNumber.from(params.lower)
    const upper = BigNumber.from(params.upper)
    const claim = BigNumber.from(params.claim)
    let liquidityAmount = params.liquidityAmount ? params.liquidityAmount : null
    let liquidityPercent = params.liquidityPercent ? params.liquidityPercent : null
    const zeroForOne = params.zeroForOne
    const balanceInIncrease = params.balanceInIncrease
    const balanceOutIncrease = params.balanceOutIncrease
    const upperTickCleared = params.upperTickCleared
    const lowerTickCleared = params.lowerTickCleared
    const revertMessage = params.revertMessage
    const expectedUpper = params.expectedUpper ? BigNumber.from(params.expectedUpper) : null
    const expectedLower = params.expectedLower ? BigNumber.from(params.expectedLower) : null
    const compareSnapshot = params.compareSnapshot ? params.compareSnapshot : true
    const positionId = BigNumber.from(params.positionId.toString())


    let balanceInBefore
    let balanceOutBefore
    if (zeroForOne) {
        balanceInBefore = await hre.props.token1.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token0.balanceOf(signer.address)
    } else {
        balanceInBefore = await hre.props.token0.balanceOf(signer.address)
        balanceOutBefore = await hre.props.token1.balanceOf(signer.address)
    }

    let lowerTickBefore: Tick
    let upperTickBefore: Tick
    let positionBefore: Position
    let positionSnapshot: Position

    if (zeroForOne) {
        lowerTickBefore = await hre.props.coverPool.ticks(lower)
        upperTickBefore = await hre.props.coverPool.ticks(upper)
        positionBefore = await hre.props.coverPool.positions0(positionId)
    } else {
        lowerTickBefore = await hre.props.coverPool.ticks(lower)
        upperTickBefore = await hre.props.coverPool.ticks(upper)
        positionBefore = await hre.props.coverPool.positions1(positionId)
    }

    if (liquidityAmount) {
        if (positionBefore.liquidity.gt(BN_ZERO)) {
            liquidityPercent = liquidityAmount.mul(ethers.utils.parseUnits("1",38)).div(positionBefore.liquidity)
            liquidityAmount = liquidityPercent.mul(positionBefore.liquidity).div(ethers.utils.parseUnits("1",38))
        }
        else if (liquidityAmount.gt(BN_ZERO))
            liquidityPercent = ethers.utils.parseUnits("1", 38);
        else
            liquidityPercent = BN_ZERO
    } else {
        liquidityAmount = liquidityPercent.mul(positionBefore.liquidity).div(ethers.utils.parseUnits("1",38))
    }

    if (revertMessage == '') {
        positionSnapshot = await hre.props.coverPool.snapshot({
            owner: signer.address,
            burnPercent: liquidityPercent,
            positionId: positionId,
            claim: claim,
            zeroForOne: zeroForOne
        })
        // console.log('BURN CALL')
        const burnTxn = await hre.props.coverPool
            .connect(signer)
            .burn({
                to: signer.address,
                positionId: positionId,
                claim: claim,
                zeroForOne: zeroForOne,
                burnPercent: liquidityPercent,
                sync: true
            })
        await burnTxn.wait()
    } else {
        await expect(
            hre.props.coverPool
                .connect(signer)
                .burn({
                    to: signer.address,
                    positionId: positionId,
                    claim: claim,
                    zeroForOne: zeroForOne,
                    burnPercent: liquidityPercent,
                    sync: true
                })
        ).to.be.revertedWith(revertMessage)
        return
    }
    let balanceInAfter
    let balanceOutAfter
    if (zeroForOne) {
        balanceInAfter = await hre.props.token1.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token0.balanceOf(signer.address)
    } else {
        balanceInAfter = await hre.props.token0.balanceOf(signer.address)
        balanceOutAfter = await hre.props.token1.balanceOf(signer.address)
    }

    expect(balanceInAfter.sub(balanceInBefore)).to.be.equal(balanceInIncrease)
    expect(balanceOutAfter.sub(balanceOutBefore)).to.be.equal(balanceOutIncrease)

    if (compareSnapshot) {
        expect(positionSnapshot.amountIn).to.be.equal(balanceInIncrease)
        expect(positionSnapshot.amountOut).to.be.equal(balanceOutIncrease)
    }

    let lowerTickAfter: Tick
    let upperTickAfter: Tick
    let positionAfter: Position

    if (zeroForOne) {
        lowerTickAfter = await hre.props.coverPool.ticks(lower)
        upperTickAfter = await hre.props.coverPool.ticks(expectedUpper ? expectedUpper : upper)
        positionAfter = await hre.props.coverPool.positions0(positionId)
    } else {
        lowerTickAfter = await hre.props.coverPool.ticks(lower)
        upperTickAfter = await hre.props.coverPool.ticks(upper)
        positionAfter = await hre.props.coverPool.positions1(positionId)
    }
    //dependent on zeroForOne
    if (zeroForOne) {
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityAmount)
            )
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
        }
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                liquidityAmount
            )
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
        }
    } else {
        //liquidity change for lower should be -liquidityAmount
        if (!lowerTickCleared) {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO.sub(liquidityAmount)
            )
        } else {
            expect(lowerTickAfter.liquidityDelta.sub(lowerTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
        }
        if (!upperTickCleared) {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                liquidityAmount
            )
        } else {
            expect(upperTickAfter.liquidityDelta.sub(upperTickBefore.liquidityDelta)).to.be.equal(
                BN_ZERO
            )
        }
    }
    const positionLiquidityAmount = params.positionLiquidityChange ? params.positionLiquidityChange : liquidityAmount
    expect(positionAfter.liquidity.sub(positionBefore.liquidity)).to.be.equal(
        BN_ZERO.sub(positionLiquidityAmount)
    )
    // console.log('position liquidity change', positionAfter.liquidity.sub(positionBefore.liquidity).toString())
}
