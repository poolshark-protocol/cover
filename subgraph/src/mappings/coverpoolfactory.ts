import { log } from '@graphprotocol/graph-ts'
import { PoolCreated } from '../../generated/CoverPoolFactory/CoverPoolFactory'
import { CoverPoolTemplate } from '../../generated/templates'
import {
    fetchTokenSymbol,
    fetchTokenName,
    fetchTokenDecimals,
} from './utils/helpers'
import { safeLoadCoverPool, safeLoadToken } from './utils/loads'
import { Address, BigInt, Bytes, ethereum } from '@graphprotocol/graph-ts'

export function handlePoolCreated(event: PoolCreated): void {
    let loadCoverPool = safeLoadCoverPool(event.params.pool.toHexString())
    let loadToken0 = safeLoadToken(event.params.token0.toHexString())
    let loadToken1 = safeLoadToken(event.params.token1.toHexString())

    let token0 = loadToken0.entity
    let token1 = loadToken1.entity
    let pool = loadCoverPool.entity

    // fetch info if null
    if (!loadToken0.exists) {
        token0.symbol = fetchTokenSymbol(event.params.token0)
        token0.name = fetchTokenName(event.params.token0)
        let decimals = fetchTokenDecimals(event.params.token0)
        // bail if we couldn't figure out the decimals
        if (decimals === null) {
            log.debug('token0 decimals null', [])
            return
        }
        token0.decimals = decimals
    }

    if (!loadToken0.exists) {
        token1.symbol = fetchTokenSymbol(event.params.token1)
        token1.name = fetchTokenName(event.params.token1)
        let decimals = fetchTokenDecimals(event.params.token1)
        // bail if we couldn't figure out the decimals
        if (decimals === null) {
            log.debug('token1 decimals null', [])
            return
        }
        token1.decimals = decimals
    }

    pool.token0 = token0.id
    pool.token1 = token1.id
    pool.tickSpread = BigInt.fromI32(event.params.tickSpread)

    pool.save()
    token0.save()
    token1.save()

    // create the tracked contract based on the template
    CoverPoolTemplate.create(event.params.pool)
}
