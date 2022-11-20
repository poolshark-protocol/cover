import { expect } from "chai";
import { BigNumber, ContractReceipt } from "ethers";
import { once } from "events";
import { getNonce, writeDeploymentsFile } from "../../../tasks/utils";
import { Token20__factory, PoolsharkHedgePoolFactory__factory, ConcentratedFactoryMock__factory, Ticks__factory, TickMath__factory } from "../../../typechain";

export class InitialSetup {

    private token0Decimals = 18;
    private token1Decimals = 18;

    constructor() {}

    public async initialSetup20AndPool(nonce: number): Promise<number> {

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

        hre.props.concentratedFactoryMock = await new ConcentratedFactoryMock__factory(hre.props.alice)
                                                        .deploy(
                                                            hre.props.token0.address,
                                                            hre.props.token1.address,
                                                            {nonce: nonce}
                                                        )
        nonce += 1;
        const ticksLib = await new Ticks__factory(hre.props.alice).deploy();
        nonce += 1;
        const tickMathLib = await new TickMath__factory(hre.props.alice).deploy();
        nonce += 1;
        hre.props.hedgePoolFactory = await new PoolsharkHedgePoolFactory__factory(
                                        {
                                            "contracts/libraries/Ticks.sol:Ticks":       ticksLib.address, 
                                            "contracts/libraries/DyDxMath.sol:DyDxMath": tickMathLib.address
                                        }, 
                                        hre.props.alice
                                    ).deploy(hre.props.concentratedFactoryMock.address, {nonce: nonce});
        nonce += 1;

        writeDeploymentsFile(
            "PoolSharkHedgePoolFactory",
            hre.props.hedgePoolFactory.address,
            hre.network.config.chainId
        );
        nonce += 1;

        hre.props.hedgePoolFactory = await ethers.getContractAt("PoolsharkHedgePoolFactory", hre.props.hedgePoolFactory.address);

        return nonce;
    }

    
};
