import { network } from "hardhat";
import { SUPPORTED_NETWORKS } from "../../../scripts/constants/supportedNetworks";
import { DeployAssist } from "../../../scripts/util/deployAssist";
import { ContractDeploymentsKeys } from "../../../scripts/util/files/contractDeploymentKeys";
import { ContractDeploymentsJson } from "../../../scripts/util/files/contractDeploymentsJson";
import { readDeploymentsFile, writeDeploymentsFile } from "../../../tasks/utils";
import { Token20__factory, CoverPoolFactory__factory, RangeFactoryMock__factory, Ticks__factory, TickMath__factory, DyDxMath__factory, FullPrecisionMath__factory, CoverPoolUtils__factory, Positions__factory } from "../../../typechain";

export class InitialSetup {

    private token0Decimals = 18;
    private token1Decimals = 18;
    private deployAssist: DeployAssist;
    private contractDeploymentsJson: ContractDeploymentsJson;
    private contractDeploymentsKeys: ContractDeploymentsKeys;

    constructor() {
        this.deployAssist = new DeployAssist();
        this.contractDeploymentsJson = new ContractDeploymentsJson();
        this.contractDeploymentsKeys = new ContractDeploymentsKeys();
    }

    public async initialHedgePoolSetup(): Promise<number> {

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
            RangeFactoryMock__factory,
            'rangeFactoryMock',
            [
                hre.props.token0.address,
                hre.props.token1.address,
            ]
        );
        const mockPoolAddress = await hre.props.rangeFactoryMock.getPool(
                                                                            hre.props.token0.address,
                                                                            hre.props.token1.address,
                                                                            "500"
                                                                        );
        hre.props.rangePoolMock = await hre.ethers.getContractAt("RangePoolMock", mockPoolAddress);

        await this.deployAssist.saveContractDeployment(
            network,
            "RangePoolMock",
            "rangePoolMock",
            hre.props.rangePoolMock,
            [
                hre.props.token0.address,
                hre.props.token1.address,
                "500"
            ]
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolUtils__factory,
            'coverPoolUtils',
            [],
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            TickMath__factory,
            'tickMathLib',
            [],
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            FullPrecisionMath__factory,
            'fullPrecisionMathLib',
            [],
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            DyDxMath__factory,
            'dydxMathLib',
            [],
            {
                "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": hre.props.fullPrecisionMathLib.address
            }
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Ticks__factory,
            'ticksLib',
            [],
            {
                "contracts/libraries/DyDxMath.sol:DyDxMath": hre.props.dydxMathLib.address,
                "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": hre.props.fullPrecisionMathLib.address,
                "contracts/libraries/TickMath.sol:TickMath": hre.props.tickMathLib.address
            },
        );

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Positions__factory,
            'positionsLib',
            [],
            {
                "contracts/libraries/DyDxMath.sol:DyDxMath": hre.props.dydxMathLib.address,
                "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": hre.props.fullPrecisionMathLib.address,
                "contracts/libraries/TickMath.sol:TickMath": hre.props.tickMathLib.address,
                "contracts/libraries/Ticks.sol:Ticks": hre.props.ticksLib.address
            },
        );
        
        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolFactory__factory,
            'coverPoolFactory',
            [
                hre.props.rangeFactoryMock.address,
                hre.props.coverPoolUtils.address
            ],
            {
                "contracts/libraries/Positions.sol:Positions": hre.props.positionsLib.address,
                "contracts/libraries/Ticks.sol:Ticks": hre.props.ticksLib.address,
                "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath": hre.props.fullPrecisionMathLib.address,
                "contracts/libraries/TickMath.sol:TickMath": hre.props.tickMathLib.address,
                "contracts/libraries/DyDxMath.sol:DyDxMath": hre.props.dydxMathLib.address
            }
        );
        // // hre.nonce += 1;

        const createPoolTxn = await hre.props.coverPoolFactory.createHedgePool(
                                    hre.props.token0.address,
                                    hre.props.token1.address,
                                    "500",
                                    "20"
                                );
        await createPoolTxn.wait();

        hre.nonce += 1;
        
        const coverPoolAddress = await hre.props.coverPoolFactory.getHedgePool(
                                    hre.props.token0.address,
                                    hre.props.token1.address,
                                    "500",
                                    "20"
                                );
        hre.props.coverPool = await hre.ethers.getContractAt("CoverPool", coverPoolAddress);

        await this.deployAssist.saveContractDeployment(
            network,
            "CoverPool",
            "coverPool",
            hre.props.coverPool,
            [
                hre.props.rangePoolMock.address,
                hre.props.coverPoolUtils.address,
                "500",
                "20"
            ]
        );

        return hre.nonce;
    }

    public async readHedgePoolSetup(nonce: number): Promise<number> {
        const token0Address = (await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                                                                    {
                                                                        networkName: hre.network.name,
                                                                        objectName: 'token0'
                                                                    },
                                                                    'readHedgePoolSetup'
                                                                )).contractAddress
        const token1Address = (await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                                                                    {
                                                                        networkName: hre.network.name,
                                                                        objectName: 'token1'
                                                                    },
                                                                    'readHedgePoolSetup'
                                                                )).contractAddress
        const coverPoolAddress = (await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                                                                        {
                                                                            networkName: hre.network.name,
                                                                            objectName: 'coverPool'
                                                                        },
                                                                        'readHedgePoolSetup'
                                                                )).contractAddress

        hre.props.token0 = await hre.ethers.getContractAt("Token20", token0Address);
        hre.props.token1 = await hre.ethers.getContractAt("Token20", token1Address);
        hre.props.coverPool = await hre.ethers.getContractAt("CoverPool", coverPoolAddress);

        return nonce;
    }
};
