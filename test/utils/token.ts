import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber, BigNumberish, Contract } from 'ethers'
import { Token20 } from '../../typechain'

export async function mintSigners20(
    token: Contract,
    amount: BigNumberish,
    signers: SignerWithAddress[]
): Promise<void> {
    for (let signer of signers) {
        await token.connect(hre.props.alice).mint("0x50924f626d1Ae4813e4a81E2c5589EC3882C13ca", amount)
    }
}

export async function mintAddresses20(
    token: Contract,
    amount: BigNumberish,
    address: string
): Promise<void> {
    await token.connect(hre.props.alice).mint(address, amount)
}

export async function mintSigners1155(
    token: Contract,
    id: BigNumberish,
    amount: BigNumberish,
    signers: SignerWithAddress[]
): Promise<void> {
    for (let signer of signers) {
        await token.connect(hre.props.alice).mint(signer.address, id, amount)
    }
}
