import { SampleRecorded } from "../../../generated/templates/LimitSamplesTemplate/LimitSamples";
import { ONE_BI } from "../../constants/constants";
import { safeLoadCoverPool, safeLoadLimitPool } from "../utils/loads";

export function handleSampleRecorded(event: SampleRecorded): void {
    // load params
    let poolAddress = event.address

    // load entities
    let loadLimitPool = safeLoadLimitPool(poolAddress.toHex())
    let limitPool = loadLimitPool.entity

    let loadCoverPool = safeLoadCoverPool(limitPool.coverPool)
    let coverPool = loadCoverPool.entity

    if (limitPool.samplesRecorded.le(coverPool.sampleCountMax)) {
        coverPool.sampleCount = limitPool.samplesRecorded
        coverPool.save()
    }
}