import { network } from 'hardhat'
import { SUPPORTED_NETWORKS } from '../../../scripts/constants/supportedNetworks'
import { DeployAssist } from '../../../scripts/util/deployAssist'
import { ContractDeploymentsKeys } from '../../../scripts/util/files/contractDeploymentKeys'
import { ContractDeploymentsJson } from '../../../scripts/util/files/contractDeploymentsJson'
import { readDeploymentsFile, writeDeploymentsFile } from '../../../tasks/utils'
import {
    Token20__factory,
    CoverPoolFactory__factory,
    UniswapV3FactoryMock,
    UniswapV3Source,
    Ticks__factory,
    TickMath__factory,
    DyDxMath__factory,
    FullPrecisionMath__factory,
    Positions__factory,
    Epochs__factory,
    Deltas__factory,
    Claims__factory,
    CoverPoolManager__factory,
    TickMap__factory,
    EpochMap__factory,
    UniswapV3Source__factory,
    UniswapV3FactoryMock__factory,
} from '../../../typechain'

export class InitialSetup {
    private token0Decimals = 18
    private token1Decimals = 18
    private uniV3String = ethers.utils.formatBytes32String('UNI-V3')
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
            UniswapV3FactoryMock__factory,
            'uniswapV3FactoryMock',
            [
                hre.props.token0.address,
                hre.props.token1.address
            ]
        )
        const mockPoolAddress = await hre.props.uniswapV3FactoryMock.getPool(
            hre.props.token0.address,
            hre.props.token1.address,
            '500'
        )

        hre.props.uniswapV3PoolMock = await hre.ethers.getContractAt('UniswapV3PoolMock', mockPoolAddress)
        await this.deployAssist.saveContractDeployment(
            network,
            'UniswapV3PoolMock',
            'uniswapV3PoolMock',
            hre.props.uniswapV3PoolMock,
            [hre.props.token0.address, hre.props.token1.address, '500']
        )

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
                'contracts/libraries/math/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            UniswapV3Source__factory,
            'uniswapV3Source',
            [
                hre.props.uniswapV3FactoryMock.address
            ]
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            TickMap__factory,
            'tickMapLib',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            EpochMap__factory,
            'epochMapLib',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Deltas__factory,
            'deltasLib',
            [],
            {
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Epochs__factory,
            'epochsLib',
            [],
            {
                'contracts/libraries/math/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/math/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/UniswapV3Source.sol:UniswapV3Source': hre.props.uniswapV3Source.address,
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
                'contracts/libraries/EpochMap.sol:EpochMap': hre.props.epochMapLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Ticks__factory,
            'ticksLib',
            [],
            {
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/math/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/math/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address
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
                'contracts/libraries/math/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
                'contracts/libraries/EpochMap.sol:EpochMap': hre.props.epochMapLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Positions__factory,
            'positionsLib',
            [],
            {
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/math/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/math/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address,
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/Claims.sol:Claims': hre.props.claimsLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
                'contracts/libraries/EpochMap.sol:EpochMap': hre.props.epochMapLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolManager__factory,
            'coverPoolManager',
            [
                this.uniV3String,
                hre.props.uniswapV3Source.address
            ]
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPoolFactory__factory,
            'coverPoolFactory',
            [   
                hre.props.coverPoolManager.address
            ],
            {
                'contracts/libraries/Positions.sol:Positions': hre.props.positionsLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address,
                'contracts/libraries/math/FullPrecisionMath.sol:FullPrecisionMath':
                    hre.props.fullPrecisionMathLib.address,
                'contracts/libraries/math/TickMath.sol:TickMath': hre.props.tickMathLib.address,
                'contracts/libraries/math/DyDxMath.sol:DyDxMath': hre.props.dydxMathLib.address,
                'contracts/libraries/Epochs.sol:Epochs': hre.props.epochsLib.address,
            }
        )

        const setFactoryTxn = await hre.props.coverPoolManager.setFactory(
            hre.props.coverPoolFactory.address
        )
        await setFactoryTxn.wait()

        hre.nonce += 1

        // create first cover pool
        let createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
            this.uniV3String,
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '20',
            '5'
        )
        await createPoolTxn.wait()

        hre.nonce += 1

        let coverPoolAddress = await hre.props.coverPoolFactory.getCoverPool(
            this.uniV3String,
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
            [hre.props.uniswapV3PoolMock.address]
        )

        // create second cover pool
        createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
            this.uniV3String,
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '40',
            '10'
        )
        await createPoolTxn.wait()

        hre.nonce += 1

        coverPoolAddress = await hre.props.coverPoolFactory.getCoverPool(
            this.uniV3String,
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '40',
            '10'
        )
        hre.props.coverPool2 = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)

        await this.deployAssist.saveContractDeployment(
            network,
            'CoverPool',
            'coverPool2',
            hre.props.coverPool2,
            [hre.props.uniswapV3PoolMock.address]
        )

        //TODO: for coverPool2 we need a second mock pool with a different cardinality

        await hre.props.uniswapV3PoolMock.setObservationCardinality('5', '5')

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

        const uniswapV3PoolMockAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'rangePoolMock',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress

        const coverPoolFactoryAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'coverPoolFactory',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress

        hre.props.token0 = await hre.ethers.getContractAt('Token20', token0Address)
        hre.props.token1 = await hre.ethers.getContractAt('Token20', token1Address)
        hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)
        hre.props.coverPoolFactory = await hre.ethers.getContractAt('CoverPoolFactory', coverPoolFactoryAddress)
        hre.props.uniswapV3PoolMock = await hre.ethers.getContractAt('UniswapV3PoolMock', uniswapV3PoolMockAddress)

        return nonce
    }

    public async createCoverPool(): Promise<void> {

        await hre.props.coverPoolFactory
          .connect(hre.props.admin)
          .createCoverPool(
            this.uniV3String,
            hre.props.token0.address,
            hre.props.token1.address,
            '500',
            '40',
            '40'
        )
        hre.nonce += 1
    }
}
