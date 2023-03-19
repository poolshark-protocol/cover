import { network } from 'hardhat'
import { SUPPORTED_NETWORKS } from '../../../scripts/constants/supportedNetworks'
import { DeployAssist } from '../../../scripts/util/deployAssist'
import { ContractDeploymentsKeys } from '../../../scripts/util/files/contractDeploymentKeys'
import { ContractDeploymentsJson } from '../../../scripts/util/files/contractDeploymentsJson'
import { readDeploymentsFile, writeDeploymentsFile } from '../../../tasks/utils'
import {
    Token20__factory,
    CoverPoolFactory__factory,
    RangeFactoryMock__factory,
    Ticks__factory,
    TickMath__factory,
    DyDxMath__factory,
    FullPrecisionMath__factory,
    Positions__factory,
    TwapOracle__factory,
    Epochs__factory,
    Deltas__factory,
    Claims__factory,
    CoverPoolManager__factory,
} from '../../../typechain'

export class InitialSetup {
    private token0Decimals = 18
    private token1Decimals = 18
    private deployAssist: DeployAssist
    private contractDeploymentsJson: ContractDeploymentsJson
    private contractDeploymentsKeys: ContractDeploymentsKeys

    constructor() {
        this.deployAssist = new DeployAssist()
        this.contractDeploymentsJson = new ContractDeploymentsJson()
        this.contractDeploymentsKeys = new ContractDeploymentsKeys()
    }

    public async initialCoverPoolSetup(): Promise<number> {
        const network = SUPPORTED_NETWORKS[hre.network.name.toUpperCase()]

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenA',
            ['Token20A', 'TOKEN20A', this.token0Decimals]
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenB',
            ['Token20B', 'TOKEN20B', this.token1Decimals]
        )

        const tokenOrder = hre.props.tokenA.address.localeCompare(hre.props.tokenB.address)
        let token0Args
        let token1Args
        if (tokenOrder < 0) {
            hre.props.token0 = hre.props.tokenA
            hre.props.token1 = hre.props.tokenB
            token0Args = ['Token20A', 'TOKEN20A', this.token0Decimals]
            token1Args = ['Token20B', 'TOKEN20B', this.token1Decimals]
        } else {
            hre.props.token0 = hre.props.tokenB
            hre.props.token1 = hre.props.tokenA
            token0Args = ['Token20B', 'TOKEN20B', this.token1Decimals]
            token1Args = ['Token20A', 'TOKEN20A', this.token0Decimals]
        }
        this.deployAssist.saveContractDeployment(
            network,
            'Token20',
            'token0',
            hre.props.token0,
            token0Args
        )
        this.deployAssist.saveContractDeployment(
            network,
            'Token20',
            'token1',
            hre.props.token1,
            token1Args
        )
        this.deployAssist.deleteContractDeployment(network, 'tokenA')
        this.deployAssist.deleteContractDeployment(network, 'tokenB')

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            RangeFactoryMock__factory,
            'rangeFactoryMock',
            [hre.props.token0.address, hre.props.token1.address]
        )
        const mockPoolAddress = await hre.props.rangeFactoryMock.getPool(
            hre.props.token0.address,
            hre.props.token1.address,
            '500'
        )
        hre.props.rangePoolMock = await hre.ethers.getContractAt('RangePoolMock', mockPoolAddress)
        console.log(1)
        await this.deployAssist.saveContractDeployment(
            network,
            'RangePoolMock',
            'rangePoolMock',
            hre.props.rangePoolMock,
            [hre.props.token0.address, hre.props.token1.address, '500']
        )
        console.log(2)
        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            TickMath__factory,
            'tickMathLib',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            FullPrecisionMath__factory,
            'fullPrecisionMathLib',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            DyDxMath__factory,
            'dydxMathLib',
            [],
            {
                'contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            TwapOracle__factory,
            'twapOracleLib',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Deltas__factory,
            'deltasLib',
            [],
            {
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Epochs__factory,
            'epochsLib',
            [],
            {
                'contracts/libraries/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/TwapOracle.sol:TwapOracle': hre.props.twapOracleLib.address,
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Ticks__factory,
            'ticksLib',
            [],
            {
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/TwapOracle.sol:TwapOracle': hre.props.twapOracleLib.address,
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Claims__factory,
            'claimsLib',
            [],
            {
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Positions__factory,
            'positionsLib',
            [],
            {
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address,
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/Claims.sol:Claims': hre.props.claimsLib.address,
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolManager__factory,
            'coverPoolManager',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolFactory__factory,
            'coverPoolFactory',
            [   
                hre.props.coverPoolManager.address,
                hre.props.rangeFactoryMock.address
            ],
            {
                'contracts/libraries/Positions.sol:Positions': hre.props.positionsLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address,
                'contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/Epochs.sol:Epochs': hre.props.epochsLib.address,
            }
        )

        const setFactoryTxn = await hre.props.coverPoolManager.setFactory(
            hre.props.coverPoolFactory.address
        )
        await setFactoryTxn.wait()

        hre.nonce += 1

        const createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '20',
            '5'
        )
        await createPoolTxn.wait()

        hre.nonce += 1

        const coverPoolAddress = await hre.props.coverPoolFactory.getCoverPool(
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '20',
            '5'
        )
        hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)

        await this.deployAssist.saveContractDeployment(
            network,
            'CoverPool',
            'coverPool',
            hre.props.coverPool,
            [hre.props.rangePoolMock.address, '500', '20', '5']
        )

        return hre.nonce
    }

    public async readCoverPoolSetup(nonce: number): Promise<number> {
        const token0Address = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'token0',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress
        const token1Address = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'token1',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress
        const coverPoolAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'coverPool',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress

        const rangePoolMockAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'rangePoolMock',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress

        hre.props.token0 = await hre.ethers.getContractAt('Token20', token0Address)
        hre.props.token1 = await hre.ethers.getContractAt('Token20', token1Address)
        hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)
        hre.props.rangePoolMock = await hre.ethers.getContractAt('RangePoolMock', rangePoolMockAddress)

        return nonce
    }
}
