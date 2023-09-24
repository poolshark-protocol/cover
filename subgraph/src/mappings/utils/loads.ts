import { Address, BigDecimal, BigInt, Bytes, log } from '@graphprotocol/graph-ts'
import { BasePrice, BurnLog, CoverPool, CoverPoolFactory, CoverPoolManager, MintLog, Position, Tick, TickDeltas, Token, VolatilityTier } from '../../../generated/schema'
import { ONE_BD, ONE_BI } from '../../constants/constants'
import {
    fetchTokenSymbol,
    fetchTokenName,
    fetchTokenDecimals,
    BIGINT_ZERO,
} from './helpers'
import { bigDecimalExponated, safeDiv } from './math'
import { getEthPriceInUSD } from './price'
import { TwapSource } from '../../../generated/schema'

class LoadBasePriceRet {
    entity: BasePrice
    exists: boolean
}
export function safeLoadBasePrice(name: string): LoadBasePriceRet {
    let exists = true

    let basePriceEntity = BasePrice.load(name)

    if (!basePriceEntity) {
        basePriceEntity = new BasePrice(name)
        exists = false
    }

    basePriceEntity.USD = getEthPriceInUSD()

    return {
        entity: basePriceEntity,
        exists: exists,
    }
}
class LoadTokenRet {
    entity: Token
    exists: boolean
}
export function safeLoadToken(address: string): LoadTokenRet {
    let exists = true

    let tokenEntity = Token.load(address)

    if (!tokenEntity) {
        tokenEntity = new Token(address)
        log.info('{}', [address])
        let tokenAddress = Address.fromString(address)
        tokenEntity.symbol = fetchTokenSymbol(tokenAddress)
        tokenEntity.name = fetchTokenName(tokenAddress)
        tokenEntity.decimals = fetchTokenDecimals(tokenAddress)

        exists = false
    }

    return {
        entity: tokenEntity,
        exists: exists,
    }
}

class LoadMintLogRet {
    entity: MintLog
    exists: boolean
}
export function safeLoadMintLog(txnHash: Bytes, pool: string, owner: string, lower: BigInt, upper: BigInt, zeroForOne: boolean): LoadMintLogRet {
    let exists = true

    let mintLogId = txnHash.toString()
                    .concat('-')
                    .concat(pool)
                    .concat('-')
                    .concat(owner)
                    .concat('-')
                    .concat(upper.toString())
                    .concat('-')
                    .concat(lower.toString())
                    .concat('-')
                    .concat(zeroForOne.toString())

    let mintLogEntity = MintLog.load(mintLogId)

    if (!mintLogEntity) {
        mintLogEntity = new MintLog(mintLogId)
        exists = false
    }

    return {
        entity: mintLogEntity,
        exists: exists,
    }
}

class LoadBurnLogRet {
    entity: BurnLog
    exists: boolean
}
export function safeLoadBurnLog(txnHash: Bytes, pool: string, owner: string, lower: BigInt, upper: BigInt, zeroForOne: boolean): LoadBurnLogRet {
    let exists = true

    let burnLogId = txnHash.toString()
                    .concat('-')
                    .concat(pool)
                    .concat('-')
                    .concat(owner)
                    .concat('-')
                    .concat(upper.toString())
                    .concat('-')
                    .concat(lower.toString())
                    .concat('-')
                    .concat(zeroForOne.toString())

    let burnLogEntity = BurnLog.load(burnLogId)

    if (!burnLogEntity) {
        burnLogEntity = new BurnLog(burnLogId)
        exists = false
    }

    return {
        entity: burnLogEntity,
        exists: exists,
    }
}

class LoadManagerRet {
    entity: CoverPoolManager
    exists: boolean
}
export function safeLoadManager(address: string): LoadManagerRet {
    let exists = true

    let managerEntity = CoverPoolManager.load(address)

    if (!managerEntity) {
        managerEntity = new CoverPoolManager(address)
        exists = false
    }

    return {
        entity: managerEntity,
        exists: exists,
    }
}

class LoadTwapSourceRet {
    entity: TwapSource
    exists: boolean
}
export function safeLoadTwapSource(address: string): LoadTwapSourceRet {
    let exists = true

    let twapSourceEntity = TwapSource.load(address)

    if (!twapSourceEntity) {
        twapSourceEntity = new TwapSource(address)
        exists = false
    }

    return {
        entity: twapSourceEntity,
        exists: exists,
    }
}

class LoadVolatilityTierRet {
    entity: VolatilityTier
    exists: boolean
}
export function safeLoadVolatilityTier(poolType: string, feeTier: BigInt, tickSpread: BigInt, twapLength: BigInt): LoadVolatilityTierRet {
    let exists = true

    let volatilityTierId = 
                            poolType
                            .concat('-')                        
                            .concat(feeTier.toString())
                            .concat('-')
                            .concat(tickSpread.toString())
                            .concat('-')
                            .concat(twapLength.toString())
    log.debug('pool volatility tier id: {}', [volatilityTierId])

    let volatilityTierEntity = VolatilityTier.load(volatilityTierId)

    if (!volatilityTierEntity) {
        volatilityTierEntity = new VolatilityTier(volatilityTierId)
        exists = false
    }

    return {
        entity: volatilityTierEntity,
        exists: exists,
    }
}

class LoadTickRet {
    entity: Tick
    exists: boolean
}
export function safeLoadTick(address: string, index: BigInt): LoadTickRet {
    let exists = true

    let tickId = address
    .concat(index.toString())

    let tickEntity = Tick.load(tickId)

    if (!tickEntity) {
        tickEntity = new Tick(tickId)
        tickEntity.pool = address
        tickEntity.index = index
        tickEntity.epochLast = ONE_BI
        // 1.0001^tick is token1/token0.
        tickEntity.price0 = bigDecimalExponated(BigDecimal.fromString('1.0001'), BigInt.fromI32(tickEntity.index.toI32()))
        tickEntity.price1 = safeDiv(ONE_BD, tickEntity.price0)
        exists = false
    }

    return {
        entity: tickEntity,
        exists: exists,
    }
}

class LoadTickDeltasRet {
    entity: TickDeltas
    exists: boolean
}
export function safeLoadTickDeltas(address: string, index: BigInt, zeroForOne: boolean): LoadTickDeltasRet {
    let exists = true

    let tickDeltasId = address
    .concat(index.toString())
    .concat(zeroForOne.toString())

    let tickDeltasEntity = TickDeltas.load(tickDeltasId)

    if (!tickDeltasEntity) {
        tickDeltasEntity = new TickDeltas(tickDeltasId)
        tickDeltasEntity.pool = address
        tickDeltasEntity.index = index
        tickDeltasEntity.zeroForOne = zeroForOne
        exists = false
    }

    return {
        entity: tickDeltasEntity,
        exists: exists,
    }
}

class LoadCoverPoolFactoryRet {
    entity: CoverPoolFactory
    exists: boolean
}
export function safeLoadCoverPoolFactory(factoryAddress: string): LoadCoverPoolFactoryRet {
    let exists = true
    let coverPoolFactoryEntity = CoverPoolFactory.load(factoryAddress)

    if (!coverPoolFactoryEntity) {
        coverPoolFactoryEntity = new CoverPoolFactory(factoryAddress)
        coverPoolFactoryEntity.poolCount = BIGINT_ZERO
        exists = false
    }

    return {
        entity: coverPoolFactoryEntity,
        exists: exists,
    }
}

class LoadCoverPoolRet {
    entity: CoverPool
    exists: boolean
}
export function safeLoadCoverPool(poolAddress: string): LoadCoverPoolRet {
    let exists = true
    let coverPoolEntity = CoverPool.load(poolAddress)

    if (!coverPoolEntity) {
        coverPoolEntity = new CoverPool(poolAddress)
        exists = false
    }

    return {
        entity: coverPoolEntity,
        exists: exists,
    }
}

class LoadPositionRet {
    entity: Position
    exists: boolean
}
export function safeLoadPosition(
    poolAddress: string,
    positionId: BigInt
): LoadPositionRet {
    let exists = true
    let fromToken: string

    let coverPositionId = poolAddress
        .concat(positionId.toString())

    let positionEntity = Position.load(coverPositionId)

    if (!positionEntity) {
        positionEntity = new Position(coverPositionId)
        positionEntity.pool = poolAddress
        positionEntity.positionId = positionId
        exists = false
    }

    return {
        entity: positionEntity,
        exists: exists,
    }
}
