import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish, Contract } from "ethers";
import { Token20 } from "../../typechain";

export async function mintSigners20(
    token: Contract,
    amount: BigNumberish,
    signers: SignerWithAddress[]
): Promise<void> {
    for (let signer of signers) {
        await token.connect(hre.props.alice).mint("0x1DcF623EDf118E4B21b4C5Dc263bb735E170F9B8", amount);
    }
}

export async function mintSigners1155(
    token: Contract,
    id: BigNumberish,
    amount: BigNumberish,
    signers: SignerWithAddress[]
): Promise<void> {
    for (let signer of signers) {
        await token.connect(hre.props.alice).mint("0x1DcF623EDf118E4B21b4C5Dc263bb735E170F9B8", id, amount);
    }
}