/* eslint-disable no-var */
import { PsharksRuntimeEnvironment } from "./CustomHardhatEnvironment";

declare global {
    var hre: PsharksRuntimeEnvironment;
    var ethers: any; // FIXME: mock out
}

export {};