
import { SampleCountInitialized } from "../../generated/templates/TwapSourceTemplate/TwapSource"
import { safeLoadCoverPool } from "./utils/loads"
import { BigInt } from '@graphprotocol/graph-ts'

export function handleSampleCountInitialized(event: SampleCountInitialized): void {
    let coverPoolParam = event.params.coverPool.toHex()
    let sampleCountParam = event.params.sampleCount
    let sampleCountMaxParam = event.params.sampleCountMax
    let sampleCountRequiredParam = event.params.sampleCountRequired

    let loadPool = safeLoadCoverPool(coverPoolParam)

    if (!loadPool.exists) {
        //error
    }

    let pool = loadPool.entity

    pool.sampleCount = BigInt.fromI32(sampleCountParam)
    pool.sampleCountMax = BigInt.fromI32(sampleCountMaxParam)
    pool.sampleCountRequired = BigInt.fromI32(sampleCountRequiredParam)

    pool.save()
}