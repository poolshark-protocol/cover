
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { HardhatRuntimeEnvironment, Network } from 'hardhat/types';
import { BeforeEachProps } from './test/utils/setup/beforeEachProps';

interface PsharksHardhatRuntimeEnvironment
    extends HardhatRuntimeEnvironment {
}

export interface PsharksRuntimeEnvironment
    extends PsharksHardhatRuntimeEnvironment {
    props: BeforeEachProps;
    adminA: SignerWithAddress;
    adminB: SignerWithAddress;
    alice: SignerWithAddress;
    bob: SignerWithAddress;
    carol: SignerWithAddress;
    isAllTestSuite: boolean;
}
