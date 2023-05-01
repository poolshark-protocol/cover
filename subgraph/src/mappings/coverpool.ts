import { Burn, Mint } from '../../generated/CoverPoolFactory/CoverPool'
import {
    Address,
    BigInt,
    Bytes,
    ethereum,
    log,
    store,
} from '@graphprotocol/graph-ts'
import {
    safeLoadCoverPool,
    safeLoadPosition,
    safeLoadTick,
    safeLoadTickDeltas,
    safeLoadToken,
} from './utils/loads'
import { ONE_BI } from './utils/constants'

export function handleMint(event: Mint): void {
    let ownerParam = event.params.owner.toHex()
    let lowerParam = event.params.lower
    let upperParam = event.params.upper 
    let zeroForOneParam = event.params.zeroForOne
    let liquidityMintedParam = event.params.liquidityMinted
    let amountInDeltaMaxMintedParam = event.params.amountInDeltaMaxMinted
    let amountOutDeltaMaxMintedParam = event.params.amountOutDeltaMaxMinted
    let poolAddress = event.address.toHex()
    let msgSender = event.transaction.from

    let lower = BigInt.fromI32(lowerParam)
    let upper = BigInt.fromI32(upperParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadPosition = safeLoadPosition(poolAddress, ownerParam, lower, upper, zeroForOneParam)
    let loadLowerTick = safeLoadTick(poolAddress, lower)
    let loadUpperTick = safeLoadTick(poolAddress, upper)
    let loadLowerTickDeltas = safeLoadTickDeltas(poolAddress, lower, zeroForOneParam)
    let loadUpperTickDeltas = safeLoadTickDeltas(poolAddress, upper, zeroForOneParam)

    let position  = loadPosition.entity
    let pool      = loadCoverPool.entity
    let lowerTick = loadLowerTick.entity
    let upperTick = loadUpperTick.entity
    let lowerTickDeltas = loadLowerTickDeltas.entity
    let upperTickDeltas = loadUpperTickDeltas.entity

    pool.liquidityGlobal = pool.liquidityGlobal.plus(liquidityMintedParam)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    // increase liquidity count
    if (!loadPosition.exists) {
        if (zeroForOneParam) {
            position.inToken = pool.token0
            position.outToken = pool.token1
        } else {
            position.inToken = pool.token1
            position.outToken = pool.token0
        }
        position.lower = lower
        position.upper = upper
        position.owner = Bytes.fromHexString(ownerParam) as Bytes
        position.createdBy = msgSender
        position.createdAtTimestamp = event.block.timestamp
        position.txnHash = event.transaction.hash
        position.pool = poolAddress
    }
    position.liquidity = position.liquidity.plus(liquidityMintedParam)
    // increase tvl count
    if (zeroForOneParam) {
        //TODO: calculate by using getAmountsForLiquidity
        // pool.totalValueLocked0 = pool.totalValueLocked0.plus()
        lowerTickDeltas.amountInDeltaMaxMinus = lowerTickDeltas.amountInDeltaMaxMinus.plus(amountInDeltaMaxMintedParam)
        lowerTickDeltas.amountInDeltaMaxMinus = lowerTickDeltas.amountInDeltaMaxMinus.plus(amountOutDeltaMaxMintedParam)
    } else {
        // pool.totalValueLocked1 = pool.totalValueLocked1.plus()
        upperTickDeltas.amountInDeltaMaxMinus = upperTickDeltas.amountInDeltaMaxMinus.plus(amountInDeltaMaxMintedParam)
        upperTickDeltas.amountInDeltaMaxMinus = upperTickDeltas.amountInDeltaMaxMinus.plus(amountOutDeltaMaxMintedParam)
    }
    pool.save()
    position.save()
    lowerTick.save()
    upperTick.save()
    lowerTickDeltas.save()
    upperTickDeltas.save()
}

export function handleBurn(event: Burn): void {
    let ownerParam = event.params.owner.toHex()
    let lowerParam = event.params.lower
    let claimParam = event.params.claim
    let upperParam = event.params.upper
    let zeroForOneParam = event.params.zeroForOne
    let liquidityBurnedParam = event.params.liquidityBurned
    let amountInDeltaMaxStashedBurnedParam = event.params.amountInDeltaMaxStashedBurned
    let amountOutDeltaMaxStashedBurnedParam = event.params.amountOutDeltaMaxStashedBurned
    let amountInDeltaMaxBurnedParam = event.params.amountInDeltaMaxBurned
    let amountOutDeltaMaxBurnedParam = event.params.amountOutDeltaMaxBurned
    let poolAddress = event.address.toHex()
    let senderParam = event.transaction.from

    let lower = BigInt.fromI32(lowerParam)
    let claim = BigInt.fromI32(claimParam)
    let upper = BigInt.fromI32(upperParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadPosition = safeLoadPosition(
        poolAddress,
        ownerParam,
        lower,
        upper,
        zeroForOneParam
    )
    let loadLowerTickDeltas = safeLoadTickDeltas(poolAddress, lower, zeroForOneParam)
    let loadUpperTickDeltas = safeLoadTickDeltas(poolAddress, upper, zeroForOneParam)

    let position  = loadPosition.entity
    let pool      = loadCoverPool.entity
    let lowerTickDeltas = loadLowerTickDeltas.entity
    let upperTickDeltas = loadUpperTickDeltas.entity

    if (!loadPosition.exists) {
        //throw an error
    }
    if (position.liquidity == liquidityBurnedParam) {
        store.remove('Position', position.id)
    } else {
        position.liquidity = position.liquidity.minus(liquidityBurnedParam)
    }
    pool.liquidityGlobal = pool.liquidityGlobal.minus(liquidityBurnedParam)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    // decrease tvl count
    if (zeroForOneParam) {
        //TODO: calculate by using getAmountsForLiquidity
        // pool.totalValueLocked0 = pool.totalValueLocked0.plus()
        lowerTickDeltas.amountInDeltaMaxMinus = lowerTickDeltas.amountInDeltaMaxMinus.minus(amountInDeltaMaxBurnedParam)
        lowerTickDeltas.amountInDeltaMaxMinus = lowerTickDeltas.amountInDeltaMaxMinus.minus(amountOutDeltaMaxBurnedParam)
    } else {
        // pool.totalValueLocked1 = pool.totalValueLocked1.plus()
        upperTickDeltas.amountInDeltaMaxMinus = upperTickDeltas.amountInDeltaMaxMinus.minus(amountInDeltaMaxBurnedParam)
        upperTickDeltas.amountInDeltaMaxMinus = upperTickDeltas.amountInDeltaMaxMinus.minus(amountOutDeltaMaxBurnedParam)
    }
    //TODO: check if Tick is empty and if so delete it

    pool.save()
    position.save()
    lowerTickDeltas.save()
    upperTickDeltas.save()
}
