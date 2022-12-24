import { network } from "hardhat";
import { SUPPORTED_NETWORKS } from "../../../scripts/constants/supportedNetworks";
import { DeployAssist } from "../../../scripts/util/deployAssist";
import { readDeploymentsFile, writeDeploymentsFile } from "../../../tasks/utils";
import { Token20__factory, PoolsharkHedgePoolFactory__factory, ConcentratedFactoryMock__factory, Ticks__factory, TickMath__factory, DyDxMath__factory, FullPrecisionMath__factory, PoolsharkHedgePoolUtils__factory } from "../../../typechain";

export class InitialSetup {

    private token0Decimals = 18;
    private token1Decimals = 18;
    private deployAssist: DeployAssist;

    constructor() {
        this.deployAssist = new DeployAssist();
    }

    public async initialHedgePoolSetup(): Promise<number> {

        // const tokenA = await new Token20__factory(hre.props.alice).deploy(
        //     "Token20A",
        //     "TOKEN20A",
        //     this.token0Decimals,
        //     {nonce: nonce}
        // );

        const network = SUPPORTED_NETWORKS[hre.network.name.toUpperCase()];

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenA',
            [
                "Token20A",
                "TOKEN20A",
                this.token0Decimals,
            ],
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenB',
            [
                "Token20B",
                "TOKEN20B",
                this.token1Decimals,
            ]
        );

        const tokenOrder = hre.props.tokenA.address.localeCompare(hre.props.tokenB.address);
        let token0Args; let token1Args;
        if(tokenOrder < 0) {
            hre.props.token0 = hre.props.tokenA;
            hre.props.token1 = hre.props.tokenB;
            token0Args = [
                "Token20A",
                "TOKEN20A",
                this.token0Decimals,
            ];
            token1Args = [
                "Token20B",
                "TOKEN20B",
                this.token1Decimals,
            ];
        }
        else{
            hre.props.token0 = hre.props.tokenB;
            hre.props.token1 = hre.props.tokenA;
            token0Args = [
                "Token20B",
                "TOKEN20B",
                this.token1Decimals,
            ];
            token1Args = [
                "Token20A",
                "TOKEN20A",
                this.token0Decimals,
            ];
        }
        this.deployAssist.saveContractDeployment(
            network,
            "Token20",
            "token0",
            hre.props.token0,
            token0Args
        );
        this.deployAssist.saveContractDeployment(
            network,
            "Token20",
            "token1",
            hre.props.token1,
            token1Args
        );
        this.deployAssist.deleteContractDeployment(
            network,
            "tokenA"
        );
        this.deployAssist.deleteContractDeployment(
            network,
            "tokenB"
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            ConcentratedFactoryMock__factory,
            'concentratedFactoryMock',
            [
                hre.props.token0.address,
                hre.props.token1.address,
            ]
        );
        const mockPoolAddress = await hre.props.concentratedFactoryMock.getPool(
                                                                            hre.props.token0.address,
                                                                            hre.props.token1.address,
                                                                            "500"
                                                                        );
        hre.props.concentratedPoolMock = await hre.ethers.getContractAt("ConcentratedPoolMock", mockPoolAddress);

        await this.deployAssist.saveContractDeployment(
            network,
            "ConcentratedPoolMock",
            "concentratedPoolMock",
            hre.props.concentratedPoolMock,
            [
                hre.props.token0.address,
                hre.props.token1.address,
                "500"
            ]
        );

        const libraries = await new PoolsharkHedgePoolUtils__factory(hre.props.alice)
                                                        .deploy(
                                                            {nonce: hre.nonce}
                                                        );

        hre.nonce += 1;

        const tickMathLib = await new TickMath__factory(hre.props.alice).deploy();
        hre.nonce += 1;
        const fullPrecisionMathLib = await new FullPrecisionMath__factory(hre.props.alice).deploy();
        hre.nonce += 1;
        const dydxMathLib = await new DyDxMath__factory(
                                        {
                                            "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": fullPrecisionMathLib.address
                                        },
                                        hre.props.alice
                            ).deploy();
        hre.nonce += 1;
        const ticksLib = await new Ticks__factory(
                                        {
                                            "contracts/libraries/DyDxMath.sol:DyDxMath": dydxMathLib.address,
                                            "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": fullPrecisionMathLib.address,
                                            "contracts/libraries/TickMath.sol:TickMath": tickMathLib.address
                                        },
                                        hre.props.alice
                        ).deploy();
        hre.nonce += 1;
        
        await this.deployAssist.saveContractDeployment(
            network,
            "ConcentratedPoolMock",
            "concentratedPoolMock",
            hre.props.concentratedPoolMock,
            [
                hre.props.token0.address,
                hre.props.token1.address,
                "500"
            ]
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            PoolsharkHedgePoolFactory__factory,
            'hedgePoolFactory',
            [
                hre.props.concentratedFactoryMock.address,
                libraries.address
            ],
            {
                "contracts/libraries/Ticks.sol:Ticks":       ticksLib.address,
                "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": fullPrecisionMathLib.address,
                "contracts/libraries/TickMath.sol:TickMath": tickMathLib.address,
                "contracts/libraries/DyDxMath.sol:DyDxMath": dydxMathLib.address
            }
        );
        hre.nonce += 1;

        const createPoolTxn = await hre.props.hedgePoolFactory.createHedgePool(
                                    hre.props.token0.address,
                                    hre.props.token1.address,
                                    "500"
                                );
        await createPoolTxn.wait();
        
        const hedgePoolAddress = await hre.props.hedgePoolFactory.getHedgePool(
                                    hre.props.token0.address,
                                    hre.props.token1.address,
                                    "500"
                                );
        hre.props.hedgePool = await hre.ethers.getContractAt("PoolsharkHedgePool", hedgePoolAddress);

        await this.deployAssist.saveContractDeployment(
            network,
            "PoolsharkHedgePool",
            "hedgePool",
            hre.props.hedgePool,
            [
                hre.props.hedgePoolFactory.address,
                hre.props.concentratedPoolMock.address,
                libraries.address,
                "500",
                "10"
            ]
        );

        return hre.nonce;
    }

    public async readHedgePoolSetup(nonce: number): Promise<number> {
        const token0Address = await readDeploymentsFile("Token0", hre.network.config.chainId);
        const token1Address = await readDeploymentsFile("Token1", hre.network.config.chainId);
        const hedgePoolAddress = await readDeploymentsFile("PoolsharkHedgePool", hre.network.config.chainId);

        hre.props.token0 = await hre.ethers.getContractAt("Token20", token0Address);
        hre.props.token1 = await hre.ethers.getContractAt("Token20", token1Address);
        hre.props.hedgePool = await hre.ethers.getContractAt("PoolsharkHedgePool", hedgePoolAddress);

        return nonce;
    }
};
