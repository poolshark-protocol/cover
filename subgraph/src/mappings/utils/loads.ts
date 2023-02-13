import { Address, BigInt, Bytes, log } from '@graphprotocol/graph-ts'
import { CoverPool, Position, Token } from '../../../generated/schema'
import {
    fetchTokenSymbol,
    fetchTokenName,
    fetchTokenDecimals,
    BIGINT_ZERO,
    BIGDECIMAL_ZERO,
} from './helpers'

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

class LoadCoverPoolRet {
    entity: CoverPool
    exists: boolean
}
export function safeLoadCoverPool(poolAddress: string): LoadCoverPoolRet {
    let exists = true
    let hedgePoolEntity = CoverPool.load(poolAddress)

    if (!hedgePoolEntity) {
        hedgePoolEntity = new CoverPool(poolAddress)

        exists = false
    }

    return {
        entity: hedgePoolEntity,
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

        exists = false
    }

    return {
        entity: positionEntity,
        exists: exists,
    }
}
