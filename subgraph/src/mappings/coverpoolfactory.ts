import { log } from '@graphprotocol/graph-ts'
import { PoolCreated } from '../../generated/CoverPoolFactory/CoverPoolFactory'
import { CoverPoolTemplate } from '../../generated/templates'
import {
    fetchTokenSymbol,
    fetchTokenName,
    fetchTokenDecimals,
} from './utils/helpers'
import { safeLoadCoverPool, safeLoadCoverPoolFactory, safeLoadTick, safeLoadToken } from './utils/loads'
import { Address, BigInt, Bytes, ethereum } from '@graphprotocol/graph-ts'

export function handlePoolCreated(event: PoolCreated): void {
    let loadCoverPool = safeLoadCoverPool(event.params.pool.toHexString())
    let loadCoverPoolFactory = safeLoadCoverPoolFactory(event.address.toHex())
    let loadToken0 = safeLoadToken(event.params.token0.toHexString())
    let loadToken1 = safeLoadToken(event.params.token1.toHexString())
    let loadMinTick = safeLoadTick(event.params.pool.toHexString(), BigInt.fromI32(887272))
    let loadMaxTick = safeLoadTick(event.params.pool.toHexString(), BigInt.fromI32(-887272))
    
    let token0 = loadToken0.entity
    let token1 = loadToken1.entity
    let pool = loadCoverPool.entity
    let factory = loadCoverPoolFactory.entity
    let minTick = loadMinTick.entity
    let maxTick = loadMaxTick.entity

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
    pool.factory = event.address.toHex()
    pool.tickSpread = BigInt.fromI32(event.params.tickSpread)

    pool.save()
    token0.save()
    token1.save()
    maxTick.save()
    minTick.save()

    // create the tracked contract based on the template
    CoverPoolTemplate.create(event.params.pool)
}
