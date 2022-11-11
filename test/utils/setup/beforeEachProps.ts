import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { getNonce } from "../../../tasks/utils";
import { OrderBook1155To20, OrderBook20, OrderBookFactory1155To20, OrderBookFactory20, OrderBookRouter1155To20, OrderBookRouter20, Token1155, Token20 } from "../../../typechain";
import { InitialSetup } from "./initialSetup";

export interface BeforeEachProps {
    orderBook20: OrderBook20;
    orderBook20Factory: OrderBookFactory20;
    orderBook20Router: OrderBookRouter20;
    token0: Token20;
    token1: Token20;
    orderBook1155To20: OrderBook1155To20;
    orderBook1155To20Factory: OrderBookFactory1155To20;
    orderBook1155To20Router: OrderBookRouter1155To20;
    token1155: Token1155;
    token1155Id: BigNumber;
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
        this.nonce = await this.initialSetup.initialSetup20(this.nonce);
        this.nonce = await this.initialSetup.initialSetup1155To20(this.nonce);
    };

    public retrieveProps(): BeforeEachProps {
        let orderBook20: OrderBook20;
        let orderBook20Factory: OrderBookFactory20;
        let orderBook20Router: OrderBookRouter20;
        let token0: Token20;
        let token1: Token20;
        let orderBook1155To20: OrderBook1155To20;
        let orderBook1155To20Factory: OrderBookFactory1155To20;
        let orderBook1155To20Router: OrderBookRouter1155To20;
        let token1155: Token1155;
        let token1155Id: BigNumber;
        let token20: Token20;
        let alice: SignerWithAddress;
        let bob: SignerWithAddress;
        let carol: SignerWithAddress;

        return {
            orderBook20,
            orderBook20Factory,
            orderBook20Router,
            token0,
            token1,
            orderBook1155To20,
            orderBook1155To20Factory,
            orderBook1155To20Router,
            token1155,
            token1155Id,
            token20,
            alice,
            bob,
            carol,
        };
    };

    
};