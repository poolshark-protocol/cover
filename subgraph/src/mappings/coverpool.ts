import { Burn, FinalDeltasAccumulated, Initialize, Mint, StashDeltasAccumulated, StashDeltasCleared, Swap } from '../../generated/CoverPoolFactory/CoverPool'
import {
    Address,
    BigDecimal,
    BigInt,
    Bytes,
    ethereum,
    log,
    store,
} from '@graphprotocol/graph-ts'
import {
    safeLoadBasePrice,
    safeLoadCoverPool,
    safeLoadCoverPoolFactory,
    safeLoadPosition,
    safeLoadTick,
    safeLoadTickDeltas,
    safeLoadToken,
} from './utils/loads'
import { ONE_BI, TWO_BD, ZERO_BD } from '../constants/constants'
import { bigInt1e38, convertTokenToDecimal } from './utils/math'
import { safeMinus } from './utils/deltas'
import { Sync } from '../../generated/templates/CoverPoolTemplate/CoverPool'
import { BIGINT_ONE, BIGINT_ZERO } from './utils/helpers'
import { AmountType, findEthPerToken, getAdjustedAmounts, sqrtPriceX96ToTokenPrices } from './utils/price'
import { FACTORY_ADDRESS } from '../constants/constants'
import { updateDerivedTVLAmounts } from './utils/tvl'

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

    let loadToken0 = safeLoadToken(pool.token0)
    let loadToken1 = safeLoadToken(pool.token1)
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity

    pool.latestTick = latest
    pool.genesisTime = genesisTimeParam
    pool.auctionEpoch = BIGINT_ONE
    pool.auctionStart = auctionStartParam
    pool.pool0Price = pool0PriceParam
    pool.pool1Price = pool1PriceParam

    let prices = sqrtPriceX96ToTokenPrices(pool0PriceParam, token0, token1)
    pool.price0 = prices[0]
    pool.price1 = prices[1]
    pool.save()

    let loadBasePrice = safeLoadBasePrice('eth')
    let basePrice = loadBasePrice.entity

    pool.save()
    minTick.save()
    maxTick.save()
    latestTick.save()
    basePrice.save()
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

    let loadBasePrice = safeLoadBasePrice('eth')
    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let basePrice = loadBasePrice.entity
    let pool = loadCoverPool.entity

    let loadCoverPoolFactory = safeLoadCoverPoolFactory(FACTORY_ADDRESS.toLowerCase())
    let loadToken0 = safeLoadToken(pool.token0)
    let loadToken1 = safeLoadToken(pool.token1)
    let factory = loadCoverPoolFactory.entity
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity

    let loadPosition = safeLoadPosition(poolAddress, ownerParam, lower, upper, zeroForOneParam)
    let loadLowerTick = safeLoadTick(poolAddress, lower)
    let loadUpperTick = safeLoadTick(poolAddress, upper)
    let loadLowerTickDeltas = safeLoadTickDeltas(poolAddress, lower, zeroForOneParam)
    let loadUpperTickDeltas = safeLoadTickDeltas(poolAddress, upper, zeroForOneParam)

    let position  = loadPosition.entity
    let lowerTick = loadLowerTick.entity
    let upperTick = loadUpperTick.entity
    let lowerTickDeltas = loadLowerTickDeltas.entity
    let upperTickDeltas = loadUpperTickDeltas.entity

    pool.liquidityGlobal = pool.liquidityGlobal.plus(liquidityMintedParam)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    // initialize tick epoch
    if (!loadLowerTick.exists) {
        lowerTick.epochLast = epochLastParam
    }
    if (!loadUpperTick.exists) {
        upperTick.epochLast = epochLastParam
    }
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
        position.zeroForOne = zeroForOneParam
        position.owner = Bytes.fromHexString(ownerParam) as Bytes
        position.epochLast = epochLastParam
        position.createdBy = msgSender
        position.createdAtTimestamp = event.block.timestamp
        position.txnHash = event.transaction.hash
        position.pool = poolAddress
    }
    position.liquidity = position.liquidity.plus(liquidityMintedParam)
    position.amountInDeltaMax = position.amountInDeltaMax.plus(amountInDeltaMaxMintedParam)
    position.amountOutDeltaMax = position.amountOutDeltaMax.plus(amountOutDeltaMaxMintedParam)
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

    let amount0 = convertTokenToDecimal(zeroForOneParam ? amountInParam : BIGINT_ZERO, token0.decimals)
    let amount1 = convertTokenToDecimal(zeroForOneParam ? BIGINT_ZERO : amountInParam, token1.decimals)

    token0.txnCount = token0.txnCount.plus(ONE_BI)
    token1.txnCount = token1.txnCount.plus(ONE_BI)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    factory.txnCount = factory.txnCount.plus(ONE_BI)

    // eth price updates
    token0.ethPrice = findEthPerToken(token0, token1)
    token1.ethPrice = findEthPerToken(token1, token0)
    token0.usdPrice = token0.ethPrice.times(basePrice.USD)
    token1.usdPrice = token1.ethPrice.times(basePrice.USD)

    let oldPoolTVLETH = pool.totalValueLockedEth
    token0.totalValueLocked = token0.totalValueLocked.plus(amount0)
    token1.totalValueLocked = token1.totalValueLocked.plus(amount1)
    pool.totalValueLocked0 = pool.totalValueLocked0.plus(amount0)
    pool.totalValueLocked1 = pool.totalValueLocked1.plus(amount1)
    let updateTvlRet = updateDerivedTVLAmounts(token0, token1, pool, factory, oldPoolTVLETH)
    token0 = updateTvlRet.token0
    token1 = updateTvlRet.token1
    pool = updateTvlRet.pool
    factory = updateTvlRet.factory

    basePrice.save()
    pool.save()
    factory.save()
    token0.save()
    token1.save()
    lowerTick.save()
    upperTick.save()
    lowerTickDeltas.save()
    upperTickDeltas.save()
    position.save()
}

export function handleBurn(event: Burn): void {
    let lowerParam = event.params.lower
    let claimParam = event.params.claim
    let upperParam = event.params.upper
    let zeroForOneParam = event.params.zeroForOne
    let liquidityBurnedParam = event.params.liquidityBurned
    let tokenInClaimedParam = event.params.tokenInClaimed
    let tokenOutClaimedParam = event.params.tokenOutClaimed
    let tokenOutBurnedParam = event.params.tokenOutBurned
    let amountInDeltaMaxStashedBurnedParam = event.params.amountInDeltaMaxStashedBurned
    let amountOutDeltaMaxStashedBurnedParam = event.params.amountOutDeltaMaxStashedBurned
    let amountInDeltaMaxBurnedParam = event.params.amountInDeltaMaxBurned
    let amountOutDeltaMaxBurnedParam = event.params.amountOutDeltaMaxBurned
    let claimPriceLastParam = event.params.claimPriceLast
    let poolAddress = event.address.toHex()
    let msgSender = event.transaction.from.toHex()

    let lower = BigInt.fromI32(lowerParam)
    let claim = BigInt.fromI32(claimParam)
    let upper = BigInt.fromI32(upperParam)

    let loadBasePrice = safeLoadBasePrice('eth')
    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadPosition = safeLoadPosition(
        poolAddress,
        msgSender,
        lower,
        upper,
        zeroForOneParam
    )

    let basePrice = loadBasePrice.entity
    let position  = loadPosition.entity
    let pool      = loadCoverPool.entity

    let loadCoverPoolFactory = safeLoadCoverPoolFactory(FACTORY_ADDRESS.toLowerCase())
    let loadToken0 = safeLoadToken(pool.token0)
    let loadToken1 = safeLoadToken(pool.token1)
    let factory = loadCoverPoolFactory.entity
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity

    let loadLowerTickDeltas = safeLoadTickDeltas(poolAddress, lower, zeroForOneParam)
    let loadClaimTickDeltas = safeLoadTickDeltas(poolAddress, claim, zeroForOneParam)
    let loadUpperTickDeltas = safeLoadTickDeltas(poolAddress, upper, zeroForOneParam)
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
    // update pool stats
    pool.liquidityGlobal = pool.liquidityGlobal.minus(liquidityBurnedParam)
    pool.txnCount = pool.txnCount.plus(ONE_BI)
    // update position delta maxes
    position.amountInDeltaMax  = safeMinus(position.amountInDeltaMax,  amountInDeltaMaxStashedBurnedParam.plus(amountInDeltaMaxBurnedParam))
    position.amountOutDeltaMax = safeMinus(position.amountOutDeltaMax, amountOutDeltaMaxStashedBurnedParam.plus(amountOutDeltaMaxBurnedParam))
    // decrease tvl count
    let amount0: BigDecimal; let amount1: BigDecimal;
    if (zeroForOneParam) {
        let tokenIn = safeLoadToken(pool.token1).entity
        let tokenOut = safeLoadToken(pool.token0).entity
        amount0 = convertTokenToDecimal(tokenOutClaimedParam.plus(tokenOutBurnedParam), tokenOut.decimals)
        amount1 = convertTokenToDecimal(tokenInClaimedParam, tokenIn.decimals)
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
        amount1 = convertTokenToDecimal(tokenOutClaimedParam.plus(tokenOutBurnedParam), tokenOut.decimals)
        amount0 = convertTokenToDecimal(tokenInClaimedParam, tokenIn.decimals)
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
        claimTickDeltas.amountOutDelta = claimTickDeltas.amountOutDelta.minus(tokenOutClaimedParam)
        claimTickDeltas.amountInDeltaMax = safeMinus(claimTickDeltas.amountInDeltaMax, amountInDeltaMaxStashedBurnedParam)
        claimTickDeltas.amountOutDeltaMax = safeMinus(claimTickDeltas.amountOutDeltaMax, amountOutDeltaMaxStashedBurnedParam)
    }
    claimTickDeltas.amountInDelta = claimTickDeltas.amountInDelta.minus(tokenInClaimedParam)
    claimTickDeltas.amountOutDelta = claimTickDeltas.amountOutDelta.minus(tokenOutClaimedParam)

    // shrink position to new size
    if (zeroForOneParam) {
        position.upper = claim
    } else {
        position.lower = claim
    }

    // eth price updates
    token0.ethPrice = findEthPerToken(token0, token1)
    token1.ethPrice = findEthPerToken(token1, token0)
    token0.usdPrice = token0.ethPrice.times(basePrice.USD)
    token1.usdPrice = token1.ethPrice.times(basePrice.USD)

    // tvl updates
    let oldPoolTotalValueLockedEth = pool.totalValueLockedEth
    token0.totalValueLocked = token0.totalValueLocked.minus(amount0)
    token1.totalValueLocked = token1.totalValueLocked.minus(amount1)
    pool.totalValueLocked0 = pool.totalValueLocked0.minus(amount0)
    pool.totalValueLocked1 = pool.totalValueLocked1.minus(amount1)
    let updateTvlRet = updateDerivedTVLAmounts(token0, token1, pool, factory, oldPoolTotalValueLockedEth)
    token0 = updateTvlRet.token0
    token1 = updateTvlRet.token1
    pool = updateTvlRet.pool
    factory = updateTvlRet.factory

    basePrice.save()
    pool.save()
    factory.save()
    token0.save()
    token1.save()
    //TODO: update liquidityDelta based on liquidity withdrawn
    // lowerTick.save()
    // upperTick.save()
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
    let loadCoverPoolFactory = safeLoadCoverPoolFactory(FACTORY_ADDRESS.toLowerCase())
    let loadBasePrice = safeLoadBasePrice('eth')

    let pool = loadCoverPool.entity
    let factory = loadCoverPoolFactory.entity
    let basePrice = loadBasePrice.entity

    let loadToken0 = safeLoadToken(pool.token0)
    let loadToken1 = safeLoadToken(pool.token1)
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity

    let amount0: BigDecimal; let amount1: BigDecimal; let prices: BigDecimal[];
    if (zeroForOneParam) {
        let tokenIn = token0
        let tokenOut = token1
        amount0 = convertTokenToDecimal(amountInParam, tokenIn.decimals)
        amount1 = convertTokenToDecimal(amountOutParam, tokenOut.decimals)
        pool.pool1Price = newPriceParam
        pool.totalValueLocked0 = pool.totalValueLocked0.plus(amount0)
        pool.totalValueLocked1 = pool.totalValueLocked1.minus(amount1)
        prices = sqrtPriceX96ToTokenPrices(pool.pool1Price, token0, token1)
        pool.price1 = prices[1]
    } else {
        let tokenIn = token1
        let tokenOut = token0
        amount1 = convertTokenToDecimal(amountInParam, tokenIn.decimals)
        amount0 = convertTokenToDecimal(amountOutParam, tokenOut.decimals)
        pool.pool0Price = newPriceParam
        pool.totalValueLocked1 = pool.totalValueLocked1.plus(amount1)
        pool.totalValueLocked0 = pool.totalValueLocked0.minus(amount0)
        prices = sqrtPriceX96ToTokenPrices(pool.pool0Price, token0, token1)
        pool.price0 = prices[0]
    }
    pool.volumeToken0 = pool.volumeToken1.plus(amount0)
    pool.volumeToken1 = pool.volumeToken1.plus(amount1)
    pool.txnCount = pool.txnCount.plus(BIGINT_ONE)
    pool.save()

    // price updates
    token0.ethPrice = findEthPerToken(token0, token1)
    token1.ethPrice = findEthPerToken(token1, token0)
    token0.usdPrice = token0.ethPrice.times(basePrice.USD)
    token1.usdPrice = token1.ethPrice.times(basePrice.USD)

    let oldPoolTVLEth = pool.totalValueLockedEth
    pool.totalValueLocked0 = pool.totalValueLocked0.plus(amount0)
    pool.totalValueLocked1 = pool.totalValueLocked1.plus(amount1)
    token0.totalValueLocked = token0.totalValueLocked.plus(amount0)
    token1.totalValueLocked = token1.totalValueLocked.plus(amount1)
    let updateTvlRet = updateDerivedTVLAmounts(token0, token1, pool, factory, oldPoolTVLEth)
    token0 = updateTvlRet.token0
    token1 = updateTvlRet.token1
    pool = updateTvlRet.pool
    factory = updateTvlRet.factory

    // update volume and fees
    let amount0Abs = amount0.times(BigDecimal.fromString(amount0.lt(ZERO_BD) ? '-1' : '1'))
    let amount1Abs = amount1.times(BigDecimal.fromString(amount1.lt(ZERO_BD) ? '-1' : '1'))
    let volumeAmounts: AmountType = getAdjustedAmounts(amount0Abs, token0, amount1Abs, token1, basePrice)
    let volumeEth = volumeAmounts.eth.div(TWO_BD)
    let volumeUsd = volumeAmounts.usd.div(TWO_BD)

    factory.volumeEthTotal = factory.volumeEthTotal.plus(volumeEth)
    factory.volumeUsdTotal = factory.volumeUsdTotal.plus(volumeUsd)
    pool.volumeToken0 = pool.volumeToken0.plus(amount0Abs)
    pool.volumeToken1 = pool.volumeToken1.plus(amount1Abs)
    pool.volumeUsd = pool.volumeUsd.plus(volumeUsd)
    pool.volumeEth = pool.volumeEth.plus(volumeEth)
    pool.volumeUsd = pool.volumeUsd.plus(volumeUsd)
    pool.volumeEth = pool.volumeEth.plus(volumeEth)
    token0.volume = token0.volume.plus(amount0Abs)
    token0.volumeUsd = token0.volumeUsd.plus(volumeUsd)
    token0.volumeEth = token0.volumeEth.plus(volumeEth)
    token1.volume = token1.volume.plus(amount1Abs)
    token1.volumeUsd = token1.volumeUsd.plus(volumeUsd)
    token1.volumeEth = token1.volumeEth.plus(volumeEth)

    basePrice.save()
    pool.save()
    factory.save()
    token0.save()
    token1.save()
    //TODO: save swap/txn data
}

export function handleSync(event: Sync): void {
    log.info('processing sync {} {}', [event.params.oldLatestTick.toString(), event.params.newLatestTick.toString()])
    let pool0PriceParam = event.params.pool0Price
    let pool1PriceParam = event.params.pool1Price
    let pool0LiquidityParam = event.params.pool0Liquidity
    let pool1LiquidityParam = event.params.pool1Liquidity
    let auctionStartParam = event.params.auctionStart
    let accumEpochParam = event.params.accumEpoch
    let oldLatestTickParam = event.params.oldLatestTick
    let newLatestTickParam = event.params.newLatestTick
    let poolAddress = event.address.toHex()

    let loadBasePrice = safeLoadBasePrice('eth')
    let loadCoverPool = safeLoadCoverPool(poolAddress)

    let basePrice = loadBasePrice.entity
    let pool = loadCoverPool.entity

    let loadToken0 = safeLoadToken(pool.token0)
    let loadToken1 = safeLoadToken(pool.token1)
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity 

    let oldLatestTick = BigInt.fromI32(oldLatestTickParam)
    let newLatestTick = BigInt.fromI32(newLatestTickParam)

    let prices: BigDecimal[]
    if (newLatestTick.gt(oldLatestTick)) {
        prices = sqrtPriceX96ToTokenPrices(pool0PriceParam, token0, token1)
    } else {
        prices = sqrtPriceX96ToTokenPrices(pool1PriceParam, token0, token1)
    }
    pool.price0 = prices[0]
    pool.price1 = prices[1]
    pool.save()

    // price updates
    token0.ethPrice = findEthPerToken(token0, token1)
    token1.ethPrice = findEthPerToken(token1, token0)
    token0.usdPrice = token0.ethPrice.times(basePrice.USD)
    token1.usdPrice = token1.ethPrice.times(basePrice.USD)

    pool.pool0Price = pool0PriceParam
    pool.pool1Price = pool1PriceParam
    pool.pool0Liquidity = pool0LiquidityParam
    pool.pool1Liquidity = pool1LiquidityParam
    pool.latestTick = newLatestTick
    pool.auctionEpoch = accumEpochParam
    pool.auctionStart = auctionStartParam

    pool.save()
}

export function handleStashDeltasCleared(event: StashDeltasCleared): void {
    let stashTickParam = event.params.stashTick
    let isPool0Param = event.params.isPool0
    let poolAddress = event.address.toHex()

    let cross = BigInt.fromI32(stashTickParam)

    let loadStashTickDeltas = safeLoadTickDeltas(poolAddress, cross, isPool0Param)

    let stashTickDeltas = loadStashTickDeltas.entity
    
    let totalInDeltaMax  = stashTickDeltas.amountInDeltaMax.plus(stashTickDeltas.amountInDeltaMaxStashed)
    let totalOutDeltaMax = stashTickDeltas.amountInDeltaMax.plus(stashTickDeltas.amountOutDeltaMaxStashed)
    let amountInDeltaChange  = stashTickDeltas.amountInDeltaMaxStashed.times(bigInt1e38()).div(totalInDeltaMax)
    let amountOutDeltaChange = stashTickDeltas.amountOutDeltaMaxStashed.times(bigInt1e38()).div(totalOutDeltaMax) 
    stashTickDeltas.amountInDelta = safeMinus(stashTickDeltas.amountInDelta, amountInDeltaChange)
    stashTickDeltas.amountOutDelta = safeMinus(stashTickDeltas.amountOutDelta, amountOutDeltaChange)
    stashTickDeltas.amountInDeltaMaxStashed = BIGINT_ZERO
    stashTickDeltas.amountOutDeltaMaxStashed = BIGINT_ZERO

    stashTickDeltas.save()
}

export function handleFinalDeltasAccumulated(event: FinalDeltasAccumulated): void {
    let amountInDeltaParam = event.params.amountInDelta
    let amountOutDeltaParam = event.params.amountOutDelta
    let auctionEpochParam = event.params.accumEpoch
    let accumTickParam = event.params.accumTick
    let isPool0Param = event.params.isPool0
    let poolAddress = event.address.toHex()

    let accum = BigInt.fromI32(accumTickParam)

    let loadCoverPool = safeLoadCoverPool(poolAddress)
    let loadAccumTick = safeLoadTick(poolAddress, accum)
    let loadAccumTickDeltas = safeLoadTickDeltas(poolAddress, accum, isPool0Param)

    let pool = loadCoverPool.entity
    let accumTick = loadAccumTick.entity
    let accumTickDeltas = loadAccumTickDeltas.entity

    pool.liquidityGlobal = pool.liquidityGlobal.minus(accumTickDeltas.liquidityMinus)
    accumTick.epochLast = auctionEpochParam
    accumTickDeltas.liquidityMinus = BIGINT_ZERO
    accumTickDeltas.amountInDelta = accumTickDeltas.amountInDelta.plus(amountInDeltaParam)
    accumTickDeltas.amountOutDelta = accumTickDeltas.amountOutDelta.plus(amountOutDeltaParam)
    accumTickDeltas.amountInDeltaMax = accumTickDeltas.amountInDeltaMax.plus(accumTickDeltas.amountInDeltaMaxMinus)
    accumTickDeltas.amountOutDeltaMax = accumTickDeltas.amountOutDeltaMax.plus(accumTickDeltas.amountOutDeltaMaxMinus)

    pool.save()
    accumTick.save()
    accumTickDeltas.save()
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
