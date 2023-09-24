import { safeLoadManager, safeLoadCoverPoolFactory, safeLoadVolatilityTier, safeLoadTwapSource } from './utils/loads'
import { BigInt, log } from '@graphprotocol/graph-ts'
import { FACTORY_ADDRESS } from '../constants/constants'
import { FactoryChanged, FeeToTransfer, OwnerTransfer, PoolTypeEnabled, ProtocolFeesCollected } from '../../generated/CoverPoolManager/CoverPoolManager'
import { VolatilityTierEnabled } from '../../generated/CoverPoolManager/CoverPoolManager'
import { TwapSourceTemplate } from '../../generated/templates'

export function handlePoolTypeEnabled(event: PoolTypeEnabled): void {
    let twapSourceAddressParam = event.params.sourceAddress
    let loadTwapSource = safeLoadTwapSource(twapSourceAddressParam.toHex())
    if (!loadTwapSource.exists) {
        TwapSourceTemplate.create(twapSourceAddressParam)
    }
    let twapSource = loadTwapSource.entity
    twapSource.save()
}

export function handleVolatilityTierEnabled(event: VolatilityTierEnabled): void {
    let feeTierParam       = BigInt.fromI32(event.params.feeTier)
    let tickSpreadParam    = BigInt.fromI32(event.params.tickSpread)
    let twapLengthParam    = BigInt.fromI32(event.params.twapLength)
    let auctionLengthParam = BigInt.fromI32(event.params.auctionLength)
    let poolTypeParam      = event.params.poolType.toHex()

    let loadManager        = safeLoadManager(event.address.toHex())
    let loadVolatilityTier = safeLoadVolatilityTier(poolTypeParam, feeTierParam, tickSpreadParam, twapLengthParam)

    let manager        = loadManager.entity
    let volatilityTier = loadVolatilityTier.entity

    volatilityTier.poolType = poolTypeParam
    volatilityTier.feeAmount  = feeTierParam
    volatilityTier.tickSpread = tickSpreadParam
    volatilityTier.twapLength = twapLengthParam
    volatilityTier.auctionLength = auctionLengthParam
    volatilityTier.createdAtTimestamp   = event.block.timestamp
    volatilityTier.createdAtBlockNumber = event.block.number
    volatilityTier.save()
    let managerFeeTiers = manager.volatilityTiers
    managerFeeTiers.push(volatilityTier.id)
    manager.volatilityTiers = managerFeeTiers
    manager.save()
}

export function handleFactoryChanged(event: FactoryChanged): void {
    let loadRangePoolFactory = safeLoadCoverPoolFactory(FACTORY_ADDRESS.toLowerCase())
    let loadManager = safeLoadManager(event.address.toHex())
    
    let manager = loadManager.entity
    let factory = loadRangePoolFactory.entity
    
    manager.factory = factory.id
    factory.manager = manager.id
    
    manager.save()
    factory.save()
}

export function handleProtocolFeesCollected(event: ProtocolFeesCollected): void {
    
}

export function handleFeeToTransfer(event: FeeToTransfer): void {
    let previousFeeToParam = event.params.previousFeeTo
    let newFeeToParam      = event.params.newFeeTo

    let loadManager = safeLoadManager(event.address.toHex())

    let manager = loadManager.entity

    manager.feeTo = newFeeToParam
 
    manager.save()
}

export function handleOwnerTransfer(event: OwnerTransfer): void {
    let previousOwnerParam = event.params.previousOwner
    let newOwnerParam      = event.params.newOwner

    let loadManager = safeLoadManager(event.address.toHex())
    let loadFactory = safeLoadCoverPoolFactory(FACTORY_ADDRESS.toLowerCase())

    let manager = loadManager.entity
    let factory = loadFactory.entity

    if(!loadManager.exists) {
        manager.feeTo = newOwnerParam
        manager.factory = FACTORY_ADDRESS.toLowerCase()
    }
    if(!loadFactory.exists) {
        factory.manager = manager.id
    }
    manager.owner = newOwnerParam

    manager.save()
    factory.save()
}