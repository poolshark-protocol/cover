import { expect } from "chai";
import { BigNumber, ContractReceipt } from "ethers";
import { once } from "events";
import { getNonce, writeDeploymentsFile } from "../../../tasks/utils";
import { Token20__factory, OrderBookFactory20__factory, OrderBookRouter20__factory, Token1155__factory, OrderBookFactory1155To20__factory, OrderBookRouter1155To20__factory } from "../../../typechain";

export class InitialSetup {

    private token0Decimals = 18;
    private token1Decimals = 18;

    constructor() {}

    public async initialSetup20(nonce: number): Promise<number> {

        const tokenA = await new Token20__factory(hre.props.alice).deploy(
            "Token20A",
            "TOKEN20A",
            this.token0Decimals,
            {nonce: nonce}
        );
        nonce += 1;
        const tokenB = await new Token20__factory(hre.props.alice).deploy(
            "Token20B",
            "TOKEN20B",
            this.token1Decimals,
            {nonce: nonce}
        );

        nonce += 1;
        const tokenOrder = tokenA.address.localeCompare(tokenB.address);
        if(tokenOrder < 0) {
            hre.props.token0 = tokenA;
            hre.props.token1 = tokenB;
        }
        else{
            hre.props.token0 = tokenB;
            hre.props.token1 = tokenA;
        }

        writeDeploymentsFile(
            "Token0",
            hre.props.token0.address,
            hre.network.config.chainId
        );
        writeDeploymentsFile(
            "Token1",
            hre.props.token1.address,
            hre.network.config.chainId
        );
        const fee = 100; // .1%

        hre.props.orderBook20Factory = await new OrderBookFactory20__factory(hre.props.alice).deploy({nonce: nonce});
        nonce += 1;

        writeDeploymentsFile(
            "OrderBook20Factory",
            hre.props.orderBook20Factory.address,
            hre.network.config.chainId
        );
        hre.props.orderBook20Router  = await new OrderBookRouter20__factory(hre.props.alice).deploy(
            hre.props.orderBook20Factory.address, 
            {nonce: nonce}
        );
        nonce += 1;
        
        writeDeploymentsFile(
            "OrderBook20Router",
            hre.props.orderBook20Router.address,
            hre.network.config.chainId
        );

        // create tokenA/tokenB book
        let txn = await hre.props.orderBook20Factory.connect(hre.props.alice).createBook(
            hre.props.token0.address,
            hre.props.token1.address,
            fee,
            BigNumber.from("0"), //makerTier
            {nonce: nonce}
        );
        await txn.wait();

        nonce += 1;

        let orderBook20Address = await hre.props.orderBook20Factory.getBook(
            hre.props.token0.address,
            hre.props.token1.address,
            fee
        );
        writeDeploymentsFile(
            "OrderBook20",
            orderBook20Address,
            hre.network.config.chainId
        );

        hre.props.orderBook20 = await ethers.getContractAt("OrderBook20", orderBook20Address);

        return nonce;
    }

    public async initialSetup1155To20(nonce: number): Promise<number> {
        const signers = await ethers.getSigners();
        hre.props.alice = signers[0];
        if(hre.network.name == "hardhat"){
            hre.props.bob   = signers[1];
            hre.carol       = signers[2];
        }
        const token1155 = await new Token1155__factory(hre.props.alice).deploy(
            "https://uri.example/api/item/{id}.json",
            {nonce: nonce}
        );
        nonce += 1;
        const token20 = await new Token20__factory(hre.props.alice).deploy(
            "Token20",
            "TOKEN20",
            this.token1Decimals,
            {nonce: nonce}
        );
        nonce += 1;
        hre.props.token1155 = token1155;
        hre.props.token1155Id = BigNumber.from("0");
        hre.props.token20   = token20;
        writeDeploymentsFile(
            "Token1155",
            hre.props.token1155.address,
            hre.network.config.chainId
        );
        writeDeploymentsFile(
            "Token20",
            hre.props.token20.address,
            hre.network.config.chainId
        );
        const fee = 1000; // .1%
        hre.props.orderBook1155To20Factory = await new OrderBookFactory1155To20__factory(hre.props.alice).deploy({nonce: nonce});
        nonce += 1;
        hre.props.orderBook1155To20Router  = await new OrderBookRouter1155To20__factory(hre.props.alice).deploy(hre.props.orderBook1155To20Factory.address, {nonce: nonce});
        nonce += 1;
        writeDeploymentsFile(
            "OrderBook1155To20Factory",
            hre.props.orderBook1155To20Factory.address,
            hre.network.config.chainId
        );
        writeDeploymentsFile(
            "OrderBook1155To20Router",
            hre.props.orderBook1155To20Router.address,
            hre.network.config.chainId
        );
        // create tokenA/tokenB book
        let txn = await hre.props.orderBook1155To20Factory.connect(hre.props.alice).createBook(
            hre.props.token1155.address,
            hre.props.token1155Id,
            hre.props.token20.address,
            fee,
            {nonce: nonce}
        );
        await txn.wait();
        nonce += 1;
        let orderBook1155To20Address = await hre.props.orderBook1155To20Factory.getBook(
            hre.props.token1155.address,
            hre.props.token1155Id,
            hre.props.token20.address,
            fee
        );
        hre.props.orderBook1155To20 = await ethers.getContractAt("OrderBook1155To20", orderBook1155To20Address);
        writeDeploymentsFile(
            "OrderBook1155To20",
            hre.props.orderBook1155To20.address,
            hre.network.config.chainId
        ); 
        return nonce;
    }
};
