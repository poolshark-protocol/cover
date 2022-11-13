import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { getNonce } from "../../../tasks/utils";
import { PoolsharkHedgePool, PoolsharkHedgePoolFactory, Token20 } from "../../../typechain";
import { InitialSetup } from "./initialSetup";

export interface BeforeEachProps {
    hedgePool: PoolsharkHedgePool;
    hedgePoolFactory: PoolsharkHedgePoolFactory;
    token0: Token20;
    token1: Token20;
    token20: Token20;
    alice: SignerWithAddress;
    bob: SignerWithAddress;
    carol: SignerWithAddress;
};

export class GetBeforeEach {

    private initialSetup: InitialSetup;
    private nonce: number;
    
    constructor() {
        this.initialSetup = new InitialSetup();
    }

    public async getBeforeEach() {
        hre.props = this.retrieveProps();
        const signers = await ethers.getSigners();
        hre.props.alice = signers[0];
        if(hre.network.name == "hardhat"){
            hre.props.bob   = signers[1];
            hre.carol       = signers[2];
        }
        this.nonce = await getNonce(hre, hre.props.alice.address);
        this.nonce = await this.initialSetup.initialSetup20AndPool(this.nonce);
    };

    public retrieveProps(): BeforeEachProps {
        let hedgePool: PoolsharkHedgePool;
        let hedgePoolFactory: PoolsharkHedgePoolFactory;
        let token0: Token20;
        let token1: Token20;
        let token20: Token20;
        let alice: SignerWithAddress;
        let bob: SignerWithAddress;
        let carol: SignerWithAddress;

        return {
            hedgePool,
            hedgePoolFactory,
            token0,
            token1,
            token20,
            alice,
            bob,
            carol,
        };
    };

    
};