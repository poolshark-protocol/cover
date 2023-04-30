import { Address, BigDecimal, BigInt, log } from '@graphprotocol/graph-ts'
import { CoverPool, CoverPoolFactory, CoverPoolManager, Position, Tick, Token, VolatilityTier } from '../../../generated/schema'
import { ONE_BD, ONE_BI } from './constants'
import {
    fetchTokenSymbol,
    fetchTokenName,
    fetchTokenDecimals,
    BIGINT_ZERO,
} from './helpers'
import { bigDecimalExponated, safeDiv } from './math'

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

class LoadVolatilityTierRet {
    entity: VolatilityTier
    exists: boolean
}
export function safeLoadVolatilityTier(twapSource: string, feeTier: BigInt, tickSpread: BigInt, twapLength: BigInt): LoadVolatilityTierRet {
    let exists = true

    let volatilityTierId = 
                            twapSource
                            .concat('-')                        
                            .concat(feeTier.toString())
                            .concat('-')
                            .concat(tickSpread.toString())
                            .concat('-')
                            .concat(twapLength.toString())

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
    owner: string,
    lower: BigInt,
    upper: BigInt,
    zeroForOne: boolean
): LoadPositionRet {
    let exists = true
    let fromToken: string

    let positionId = poolAddress
        .concat(owner)
        .concat(lower.toString())
        .concat(upper.toString())
        .concat(zeroForOne.toString())

    let positionEntity = Position.load(positionId)

    if (!positionEntity) {
        positionEntity = new Position(positionId)
        positionEntity.epochLast = ONE_BI
        exists = false
    }

    return {
        entity: positionEntity,
        exists: exists,
    }
}
