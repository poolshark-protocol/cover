import { Burn, FinalDeltasAccumulated, Initialize, Mint, StashDeltasAccumulated, Swap } from '../../generated/CoverPoolFactory/CoverPool'
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
import { convertTokenToDecimal } from './utils/math'
import { safeMinus } from './utils/deltas'
import { Sync } from '../../generated/templates/CoverPoolTemplate/CoverPool'
import { BIGINT_ONE, BIGINT_ZERO } from './utils/helpers'

export function handleInitialize(event: Initialize): void {
    let minTickParam = event.params.minTick
    let maxTickParam = event.params.maxTick
    let latestTickParam = event.params.latestTick
    let genesisTimeParam = event.params.genesisTime
    let auctionStartParam = event.params.auctionStart
    let pool0PriceParam = event.params.pool0Price
    let pool1PriceParam = event.params.pool1Price
    let poolAddress = event.address.toHex()

    let min = BigInt.fromI32(minTickParam)
    let max = BigInt.fromI32(maxTickParam)
    let latest = BigInt.fromI32(latestTickParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadMinTick = safeLoadTick(poolAddress, min)
    let loadMaxTick = safeLoadTick(poolAddress, max)
    let loadLatestTick = safeLoadTick(poolAddress, latest)

    let pool = loadCoverPool.entity
    let minTick = loadMinTick.entity
    let maxTick = loadMaxTick.entity
    let latestTick = loadLatestTick.entity

    pool.latestTick = latest
    pool.genesisTime = genesisTimeParam
    pool.auctionEpoch = BIGINT_ONE
    pool.auctionStart = auctionStartParam
    pool.pool0Price = pool0PriceParam
    pool.pool1Price = pool1PriceParam

    pool.save()
    minTick.save()
    maxTick.save()
    latestTick.save()
}

export function handleMint(event: Mint): void {
    let ownerParam = event.params.to.toHex()
    let lowerParam = event.params.lower
    let upperParam = event.params.upper 
    let zeroForOneParam = event.params.zeroForOne
    let epochLastParam = event.params.epochLast
    let amountInParam = event.params.amountIn
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
        position.epochLast = epochLastParam
        position.createdBy = msgSender
        position.createdAtTimestamp = event.block.timestamp
        position.txnHash = event.transaction.hash
        position.pool = poolAddress
    }
    position.liquidity = position.liquidity.plus(liquidityMintedParam)
    // increase tvl count
    if (zeroForOneParam) {
        let tokenIn = safeLoadToken(pool.token0).entity
        pool.totalValueLocked0 = pool.totalValueLocked0.plus(convertTokenToDecimal(amountInParam, tokenIn.decimals))
        lowerTickDeltas.amountInDeltaMaxMinus = lowerTickDeltas.amountInDeltaMaxMinus.plus(amountInDeltaMaxMintedParam)
        lowerTickDeltas.amountOutDeltaMaxMinus = lowerTickDeltas.amountOutDeltaMaxMinus.plus(amountOutDeltaMaxMintedParam)
    } else {
        let tokenIn = safeLoadToken(pool.token1).entity
        pool.totalValueLocked1 = pool.totalValueLocked1.plus(convertTokenToDecimal(amountInParam, tokenIn.decimals))
        upperTickDeltas.amountInDeltaMaxMinus = upperTickDeltas.amountInDeltaMaxMinus.plus(amountInDeltaMaxMintedParam)
        upperTickDeltas.amountOutDeltaMaxMinus = upperTickDeltas.amountOutDeltaMaxMinus.plus(amountOutDeltaMaxMintedParam)
    }
    pool.save()
    position.save()
    lowerTick.save()
    upperTick.save()
    lowerTickDeltas.save()
    upperTickDeltas.save()
}

export function handleBurn(event: Burn): void {
    let msgSender = event.transaction.from.toHex()
    let lowerParam = event.params.lower
    let claimParam = event.params.claim
    let upperParam = event.params.upper
    let zeroForOneParam = event.params.zeroForOne
    let liquidityBurnedParam = event.params.liquidityBurned
    let tokenInAmountParam = zeroForOneParam ? event.params.token1Amount : event.params.token0Amount
    let tokenOutAmountParam = zeroForOneParam ? event.params.token0Amount : event.params.token1Amount
    let amountInDeltaMaxStashedBurnedParam = event.params.amountInDeltaMaxStashedBurned
    let amountOutDeltaMaxStashedBurnedParam = event.params.amountOutDeltaMaxStashedBurned
    let amountInDeltaMaxBurnedParam = event.params.amountInDeltaMaxBurned
    let amountOutDeltaMaxBurnedParam = event.params.amountOutDeltaMaxBurned
    let claimPriceLastParam = event.params.claimPriceLast
    let poolAddress = event.address.toHex()
    let senderParam = event.transaction.from

    let lower = BigInt.fromI32(lowerParam)
    let claim = BigInt.fromI32(claimParam)
    let upper = BigInt.fromI32(upperParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadPosition = safeLoadPosition(
        poolAddress,
        msgSender,
        lower,
        upper,
        zeroForOneParam
    )
    let loadLowerTickDeltas = safeLoadTickDeltas(poolAddress, lower, zeroForOneParam)
    let loadClaimTickDeltas = safeLoadTickDeltas(poolAddress, claim, zeroForOneParam)
    let loadUpperTickDeltas = safeLoadTickDeltas(poolAddress, upper, zeroForOneParam)

    let position  = loadPosition.entity
    let pool      = loadCoverPool.entity
    let lowerTickDeltas = loadLowerTickDeltas.entity
    let claimTickDeltas = loadClaimTickDeltas.entity
    let upperTickDeltas = loadUpperTickDeltas.entity

    if (!loadPosition.exists) {
        //throw an error
    }
    if (position.liquidity == liquidityBurnedParam) {
        store.remove('Position', position.id)
    } else {
        // update id if position is shrunk
        if (claim != (zeroForOneParam ? upper : lower))
            position.id = poolAddress
            .concat(msgSender)
            .concat(zeroForOneParam ? lower.toString() : claim.toString())
            .concat(zeroForOneParam ? claim.toString() : upper.toString())
            .concat(zeroForOneParam.toString())
        position.liquidity = position.liquidity.minus(liquidityBurnedParam)
        position.claimPriceLast = claimPriceLastParam
    }
    pool.liquidityGlobal = pool.liquidityGlobal.minus(liquidityBurnedParam)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    // decrease tvl count
    if (zeroForOneParam) {
        let tokenIn = safeLoadToken(pool.token1).entity
        let tokenOut = safeLoadToken(pool.token0).entity
        pool.totalValueLocked1 = pool.totalValueLocked1.minus(convertTokenToDecimal(tokenInAmountParam, tokenIn.decimals))
        pool.totalValueLocked0 = pool.totalValueLocked0.minus(convertTokenToDecimal(tokenOutAmountParam, tokenIn.decimals))
        if (claim != (zeroForOneParam ? lower : upper)) {
            lowerTickDeltas.amountInDeltaMaxMinus = safeMinus(lowerTickDeltas.amountInDeltaMaxMinus, amountInDeltaMaxBurnedParam)
            lowerTickDeltas.amountOutDeltaMaxMinus = safeMinus(lowerTickDeltas.amountOutDeltaMaxMinus, amountOutDeltaMaxBurnedParam)
        } else {
            lowerTickDeltas.amountInDeltaMax = safeMinus(lowerTickDeltas.amountInDeltaMax, amountInDeltaMaxBurnedParam)
            lowerTickDeltas.amountOutDeltaMax = safeMinus(lowerTickDeltas.amountOutDeltaMax, amountOutDeltaMaxBurnedParam)
        } 
    } else {
        let tokenIn = safeLoadToken(pool.token0).entity
        let tokenOut = safeLoadToken(pool.token1).entity
        pool.totalValueLocked1 = pool.totalValueLocked1.minus(convertTokenToDecimal(tokenOutAmountParam, tokenOut.decimals))
        pool.totalValueLocked0 = pool.totalValueLocked0.minus(convertTokenToDecimal(tokenInAmountParam, tokenIn.decimals))
        if (claim != (zeroForOneParam ? lower : upper)) {
            upperTickDeltas.amountInDeltaMaxMinus = safeMinus(upperTickDeltas.amountInDeltaMaxMinus, amountInDeltaMaxBurnedParam)
            upperTickDeltas.amountOutDeltaMaxMinus = safeMinus(upperTickDeltas.amountOutDeltaMaxMinus, amountOutDeltaMaxBurnedParam)
        } else {
            upperTickDeltas.amountInDeltaMax = safeMinus(upperTickDeltas.amountInDeltaMax, amountInDeltaMaxBurnedParam)
            upperTickDeltas.amountOutDeltaMax = safeMinus(upperTickDeltas.amountOutDeltaMax, amountOutDeltaMaxBurnedParam) 
        }
    }
    if (claim != (zeroForOneParam ? lower : upper)) {
        claimTickDeltas.amountInDeltaMaxStashed = safeMinus(claimTickDeltas.amountInDeltaMaxStashed, amountInDeltaMaxStashedBurnedParam)
        claimTickDeltas.amountOutDeltaMaxStashed = safeMinus(claimTickDeltas.amountOutDeltaMaxStashed, amountOutDeltaMaxStashedBurnedParam)
    } else {
        claimTickDeltas.amountOutDelta = claimTickDeltas.amountOutDelta.minus(tokenOutAmountParam)
        claimTickDeltas.amountInDeltaMax = safeMinus(claimTickDeltas.amountInDeltaMax, amountInDeltaMaxStashedBurnedParam)
        claimTickDeltas.amountOutDeltaMax = safeMinus(claimTickDeltas.amountOutDeltaMax, amountOutDeltaMaxStashedBurnedParam)
    }
    claimTickDeltas.amountInDelta = claimTickDeltas.amountInDelta.minus(tokenInAmountParam)
    // stash burned vs. minus burned will tell us the portion of tokenOutAmount which came from the position update vs. the liquidity removal

    // shrink position to new size
    if (zeroForOneParam) {
        position.upper = claim
    } else {
        position.lower = claim
    }
    pool.save()
    position.save()
    lowerTickDeltas.save()
    claimTickDeltas.save()
    upperTickDeltas.save()
}

export function handleSwap(event: Swap): void {
    let msgSender = event.transaction.from
    let recipientParam = event.params.recipient
    let amountInParam = event.params.amountIn
    let amountOutParam = event.params.amountOut
    let newPriceParam = event.params.newPrice
    let priceLimitParam = event.params.priceLimit
    let zeroForOneParam = event.params.zeroForOne
    let poolAddress = event.address.toHex()

    let loadCoverPool = safeLoadCoverPool(poolAddress)

    let pool = loadCoverPool.entity

    if (zeroForOneParam) {
        let tokenIn = safeLoadToken(pool.token0).entity
        let tokenOut = safeLoadToken(pool.token1).entity
        pool.pool1Price = newPriceParam
        pool.volumeToken1 = pool.volumeToken1.plus(convertTokenToDecimal(amountOutParam, tokenOut.decimals))
        pool.totalValueLocked0 = pool.totalValueLocked0.plus(convertTokenToDecimal(amountInParam, tokenIn.decimals))
        pool.totalValueLocked1 = pool.totalValueLocked1.minus(convertTokenToDecimal(amountOutParam, tokenOut.decimals))
    } else {
        let tokenIn = safeLoadToken(pool.token1).entity
        let tokenOut = safeLoadToken(pool.token0).entity
        pool.pool0Price = newPriceParam
        pool.volumeToken0 = pool.volumeToken0.plus(convertTokenToDecimal(amountOutParam, tokenOut.decimals))
        pool.totalValueLocked1 = pool.totalValueLocked1.plus(convertTokenToDecimal(amountInParam, tokenIn.decimals))
        pool.totalValueLocked0 = pool.totalValueLocked0.minus(convertTokenToDecimal(amountOutParam, tokenOut.decimals))
    }
    pool.txnCount = pool.txnCount.plus(BIGINT_ONE)

    pool.save()
}

export function handleSync(event: Sync): void {
    let pool0PriceParam = event.params.pool0Price
    let pool1PriceParam = event.params.pool1Price
    let pool0LiquidityParam = event.params.pool0Liquidity
    let pool1LiquidityParam = event.params.pool1Liquidity
    let auctionStartParam = event.params.auctionStart
    let accumEpochParam = event.params.accumEpoch
    let oldLatestTickParam = event.params.oldLatestTick
    let newLatestTickParam = event.params.newLatestTick
    let poolAddress = event.address.toHex()

    let loadCoverPool = safeLoadCoverPool(poolAddress)

    let pool = loadCoverPool.entity

    let newLatestTick = BigInt.fromI32(newLatestTickParam)

    pool.pool0Price = pool0PriceParam
    pool.pool1Price = pool1PriceParam
    pool.pool0Liquidity = pool0LiquidityParam
    pool.pool1Liquidity = pool1LiquidityParam
    pool.latestTick = newLatestTick
    pool.auctionEpoch = accumEpochParam
    pool.auctionStart = auctionStartParam

    pool.save()
}

export function handleFinalDeltasAccumulated(event: FinalDeltasAccumulated): void {
    let amountInDeltaParam = event.params.amountInDelta
    let amountOutDeltaParam = event.params.amountOutDelta
    let auctionEpochParam = event.params.accumEpoch
    let accumTickParam = event.params.accumTick
    let crossTickParam = event.params.crossTick
    let isPool0Param = event.params.isPool0
    let poolAddress = event.address.toHex()

    let accum = BigInt.fromI32(accumTickParam)
    let cross = BigInt.fromI32(crossTickParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadAccumTick = safeLoadTick(poolAddress, accum)
    let loadAccumTickDeltas = safeLoadTickDeltas(poolAddress, accum, isPool0Param)
    let loadCrossTickDeltas = safeLoadTickDeltas(poolAddress, cross, isPool0Param)

    let pool = loadCoverPool.entity
    let accumTick = loadAccumTick.entity
    let accumTickDeltas = loadAccumTickDeltas.entity
    let crossTickDeltas = loadCrossTickDeltas.entity

    pool.liquidityGlobal = pool.liquidityGlobal.minus(accumTickDeltas.liquidityMinus)
    accumTick.epochLast = auctionEpochParam
    //TODO: subtract from crossTickDeltas.amonutIn/OutDelta based on amountDeltaMaxStashed / (amountDeltaMaxStashed + amountDeltaMax)
    crossTickDeltas.amountInDeltaMaxStashed = BIGINT_ZERO
    crossTickDeltas.amountOutDeltaMaxStashed = BIGINT_ZERO
    accumTickDeltas.liquidityMinus = BIGINT_ZERO
    accumTickDeltas.amountInDelta = accumTickDeltas.amountInDelta.plus(amountInDeltaParam)
    accumTickDeltas.amountOutDelta = accumTickDeltas.amountOutDelta.plus(amountOutDeltaParam)
    accumTickDeltas.amountInDeltaMax = accumTickDeltas.amountInDeltaMax.plus(accumTickDeltas.amountInDeltaMaxMinus)
    accumTickDeltas.amountOutDeltaMax = accumTickDeltas.amountOutDeltaMax.plus(accumTickDeltas.amountOutDeltaMaxMinus)

    pool.save()
    accumTick.save()
    accumTickDeltas.save()
    crossTickDeltas.save()
}

export function handleStashDeltasAccumulated(event: StashDeltasAccumulated): void {
    let amountInDeltaParam = event.params.amountInDelta
    let amountOutDeltaParam = event.params.amountOutDelta
    let amountInDeltaMaxStashedParam = event.params.amountInDeltaMaxStashed
    let amountOutDeltaMaxStashedParam = event.params.amountOutDeltaMaxStashed
    let auctionEpochParam = event.params.accumEpoch
    let stashTickParam = event.params.stashTick
    let isPool0Param = event.params.isPool0
    let poolAddress = event.address.toHex()

    let stash = BigInt.fromI32(stashTickParam)

    let loadStashTick = safeLoadTick(poolAddress, stash)
    let loadStashTickDeltas = safeLoadTickDeltas(poolAddress, stash, isPool0Param)

    let stashTick = loadStashTick.entity
    let stashTickDeltas = loadStashTickDeltas.entity

    stashTick.epochLast = auctionEpochParam
    stashTickDeltas.amountInDelta = stashTickDeltas.amountInDelta.plus(amountInDeltaParam)
    stashTickDeltas.amountOutDelta = stashTickDeltas.amountOutDelta.plus(amountOutDeltaParam)
    stashTickDeltas.amountInDeltaMaxStashed = stashTickDeltas.amountInDeltaMaxStashed.plus(amountInDeltaMaxStashedParam)
    stashTickDeltas.amountOutDeltaMaxStashed = stashTickDeltas.amountOutDeltaMaxStashed.plus(amountOutDeltaMaxStashedParam)

    stashTick.save()
    stashTickDeltas.save()
}
