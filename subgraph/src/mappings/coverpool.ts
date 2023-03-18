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
    safeLoadToken,
} from './utils/loads'
import { Position } from '../../generated/schema'

export function handleMint(event: Mint): void {
    let ownerParam = event.params.owner.toHex()
    let lowerParam = event.params.lower
    let upperParam = event.params.upper 
    let zeroForOneParam = event.params.zeroForOne
    let liquidityMintedParam = event.params.liquidityMinted
    let poolAddress = event.address.toHex()
    let msgSender = event.transaction.from

    let lower = BigInt.fromI32(lowerParam)
    let upper = BigInt.fromI32(upperParam)

    let loadLowerTick = safeLoadTick(
        poolAddress,
        lower
    )
    let loadUpperTick = safeLoadTick(
        poolAddress,
        upper
    )
    let loadPosition = safeLoadPosition(
        poolAddress,
        ownerParam,
        lower,
        upper,
        zeroForOneParam
    )
    let loadCoverPool = safeLoadCoverPool(poolAddress)

    let position = loadPosition.entity
    let pool = loadCoverPool.entity
    let lowerTick = loadLowerTick.entity
    let upperTick = loadUpperTick.entity

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
    position.save()
    lowerTick.save()
    upperTick.save()
}

export function handleBurn(event: Burn): void {
    let ownerParam = event.params.owner.toHex()
    let lowerParam = event.params.lower
    let upperParam = event.params.upper
    let zeroForOneParam = event.params.zeroForOne
    let liquidityBurnedParam = event.params.liquidityBurned
    let poolAddress = event.address.toHex()
    let senderParam = event.transaction.from

    let lower = BigInt.fromI32(lowerParam)
    let upper = BigInt.fromI32(upperParam)

    let loadPosition = safeLoadPosition(
        poolAddress,
        ownerParam,
        lower,
        upper,
        zeroForOneParam
    )
    let loadCoverPool = safeLoadCoverPool(poolAddress)

    let position = loadPosition.entity
    let pool = loadCoverPool.entity

    if (!loadPosition.exists) {
        //throw an error
    }
    if (position.liquidity == liquidityBurnedParam) {
        store.remove('Position', position.id)
    } else {
        position.liquidity = position.liquidity.minus(liquidityBurnedParam)
    }
    position.save()
}
