import { SUPPORTED_NETWORKS } from '../../../scripts/constants/supportedNetworks'
import { DeployAssist } from '../../../scripts/util/deployAssist'
import { ContractDeploymentsKeys } from '../../../scripts/util/files/contractDeploymentKeys'
import { ContractDeploymentsJson } from '../../../scripts/util/files/contractDeploymentsJson'
import { CoverPool__factory, PoolsharkRouter__factory, PositionERC1155__factory, QuoteCall__factory, Token20Batcher__factory } from '../../../typechain'
import { BurnCall__factory } from '../../../typechain'
import { SwapCall__factory } from '../../../typechain'
import { MintCall__factory } from '../../../typechain'
import {
    Token20__factory,
    CoverPoolFactory__factory,
    Ticks__factory,
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
import { BN_ZERO, CoverPoolParams, VolatilityTier } from '../contracts/coverpool'

export class InitialSetup {
    private token0Decimals = 18
    private token1Decimals = 18
    private uniV3String = ethers.utils.formatBytes32String('UNI-V3')
    private constantProductString =  ethers.utils.formatBytes32String('CONSTANT-PRODUCT')
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
        
        // const token0Address = (
        //     await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
        //       {
        //         networkName: hre.network.name,
        //         objectName: 'token0',
        //       },
        //       'readRangePoolSetup'
        //     )
        //   ).contractAddress
        //   const token1Address = (
        //     await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
        //       {
        //         networkName: hre.network.name,
        //         objectName: 'token1',
        //       },
        //       'readRangePoolSetup'
        //     )
        //   ).contractAddress
        //   hre.props.token0 = await hre.ethers.getContractAt('Token20', token0Address)
        //   hre.props.token1 = await hre.ethers.getContractAt('Token20', token1Address)
        // await this.deployAssist.deployContractWithRetry(
        //     network,
        //     // @ts-ignore
        //     Token20Batcher__factory,
        //     'token20Batcher',
        //     []
        // )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenA',
            ['Wrapped Ether', 'WETH', this.token0Decimals]
          )
      
          await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Token20__factory,
            'tokenB',
            ['Dai Stablecoin', 'DAI', this.token1Decimals]
          )

        const tokenOrder = hre.props.tokenA.address.localeCompare(hre.props.tokenB.address) < 0
        let token0Args
        let token1Args
        if (tokenOrder) {
            hre.props.token0 = hre.props.tokenA
            hre.props.token1 = hre.props.tokenB
            token0Args = ['Wrapped Ether', 'WETH', this.token0Decimals]
            token1Args = ['Dai Stablecoin', 'DAI', this.token1Decimals]
        } else {
            hre.props.token0 = hre.props.tokenB
            hre.props.token1 = hre.props.tokenA
            token0Args = ['Dai Stablecoin', 'DAI', this.token1Decimals]
            token1Args = ['Wrapped Ether', 'WETH', this.token0Decimals]
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
            [hre.props.token0.address, hre.props.token1.address, '500', '10']
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
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            Epochs__factory,
            'epochsLib',
            [],
            {
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
                'contracts/libraries/Claims.sol:Claims': hre.props.claimsLib.address
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
                hre.props.coverPoolManager.address
            ]
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            MintCall__factory,
            'mintCall',
            [],
            {
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
                'contracts/libraries/EpochMap.sol:EpochMap': hre.props.epochMapLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            BurnCall__factory,
            'burnCall',
            [],
            {
                'contracts/libraries/Claims.sol:Claims': hre.props.claimsLib.address,
                'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
                'contracts/libraries/EpochMap.sol:EpochMap': hre.props.epochMapLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            SwapCall__factory,
            'swapCall',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            QuoteCall__factory,
            'quoteCall',
            []
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            CoverPool__factory,
            'coverPoolImpl',
            [
                hre.props.coverPoolFactory.address
            ],
            {
                'contracts/libraries/Positions.sol:Positions': hre.props.positionsLib.address,
                'contracts/libraries/Ticks.sol:Ticks': hre.props.ticksLib.address,
                'contracts/libraries/Epochs.sol:Epochs': hre.props.epochsLib.address,
                'contracts/libraries/pool/MintCall.sol:MintCall': hre.props.mintCall.address,
                'contracts/libraries/pool/BurnCall.sol:BurnCall': hre.props.burnCall.address,
                'contracts/libraries/pool/SwapCall.sol:SwapCall': hre.props.swapCall.address,
                'contracts/libraries/pool/QuoteCall.sol:QuoteCall': hre.props.quoteCall.address
            }
        )

        await this.deployAssist.deployContractWithRetry(
            network,
            // @ts-ignore
            PositionERC1155__factory,
            'positionERC1155',
            [
              hre.props.coverPoolFactory.address
            ]
        )

        const enableImplTxn = await hre.props.coverPoolManager.enablePoolType(
            this.uniV3String,
            hre.props.coverPoolImpl.address,
            hre.props.positionERC1155.address,
            hre.props.uniswapV3Source.address
        )
        await enableImplTxn.wait();

        hre.nonce += 1;

        await this.deployAssist.deployContractWithRetry(
            network,
            //@ts-ignore
            PoolsharkRouter__factory,
            'poolRouter',
            [
              hre.props.coverPoolImpl.address,
              hre.props.coverPoolFactory.address //TODO: needs to be coverPoolFactory
            ]
        )

        const volTier1: VolatilityTier = {
            minAmountPerAuction: BN_ZERO,
            auctionLength: 5,
            blockTime: 1000,
            syncFee: 0,
            fillFee: 0,
            minPositionWidth: 1,
            minAmountLowerPriced: true
        }

        const enableVolTier1 = await hre.props.coverPoolManager.enableVolatilityTier(
            this.uniV3String,
            500, // feeTier
            20,  // tickSpread
            5,   // auctionLength (seconds)
            volTier1
        )
        await enableVolTier1.wait();

        hre.nonce += 1;

        const volTier2: VolatilityTier = {
            minAmountPerAuction: BN_ZERO,
            auctionLength: 10,
            blockTime: 1000,
            syncFee: 500,
            fillFee: 5000,
            minPositionWidth: 5,
            minAmountLowerPriced: false
        }

        const enableVolTier2 = await hre.props.coverPoolManager.enableVolatilityTier(
            this.uniV3String,
            500, // feeTier
            40,  // tickSpread
            10,  // auctionLength (seconds)
            volTier2
        )
        await enableVolTier2.wait();

        hre.nonce += 1;

        const setFactoryTxn = await hre.props.coverPoolManager.setFactory(
            hre.props.coverPoolFactory.address
        )
        await setFactoryTxn.wait()

        hre.nonce += 1

        const poolParams1: CoverPoolParams = {
            poolType: this.uniV3String,
            tokenIn: hre.props.token0.address,
            tokenOut: hre.props.token1.address,
            feeTier: 500,
            tickSpread: 20,
            twapLength: 5
        }

        // create first cover pool
        let createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
            poolParams1
        )
        await createPoolTxn.wait()

        hre.nonce += 1

        let coverPoolAddress; let coverPoolTokenAddress;
        [coverPoolAddress, coverPoolTokenAddress] = await hre.props.coverPoolFactory.getCoverPool(
            poolParams1
        )
        hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)
        hre.props.coverPoolToken = await hre.ethers.getContractAt('PositionERC1155', coverPoolTokenAddress)

        await this.deployAssist.saveContractDeployment(
            network,
            'CoverPool',
            'coverPool',
            hre.props.coverPool,
            [hre.props.uniswapV3PoolMock.address]
        )

        const poolParams2: CoverPoolParams = {
            poolType: this.uniV3String,
            tokenIn: hre.props.token0.address,
            tokenOut: hre.props.token1.address,
            feeTier: 500,
            tickSpread: 40,
            twapLength: 10
        }

        // create second cover pool
        createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
            poolParams2
        )
        await createPoolTxn.wait()

        hre.nonce += 1

        coverPoolAddress = await hre.props.coverPoolFactory.getCoverPool(
            poolParams2
        )
        hre.props.coverPool2 = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)

        await this.deployAssist.saveContractDeployment(
            network,
            'CoverPool',
            'coverPool2',
            hre.props.coverPool2,
            [hre.props.uniswapV3PoolMock.address]
        )

        await hre.props.uniswapV3PoolMock.setObservationCardinality('10', '10')

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
                    objectName: 'uniswapV3PoolMock',
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
        const token20BatcherAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'token20Batcher',
                },
                'readCoverPoolSetup'
            )
        ).contractAddress

        hre.props.token0 = await hre.ethers.getContractAt('Token20', token0Address)
        hre.props.token1 = await hre.ethers.getContractAt('Token20', token1Address)
        hre.props.token20Batcher = await hre.ethers.getContractAt('Token20Batcher', token20BatcherAddress)
        hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)
        hre.props.coverPoolFactory = await hre.ethers.getContractAt('CoverPoolFactory', coverPoolFactoryAddress)
        hre.props.uniswapV3PoolMock = await hre.ethers.getContractAt('UniswapV3PoolMock', uniswapV3PoolMockAddress)

        return nonce
    }

    public async createCoverPool(): Promise<void> {

        const poolParams: CoverPoolParams = {
            poolType: this.uniV3String,
            tokenIn: hre.props.token0.address,
            tokenOut: hre.props.token1.address,
            feeTier: 500,
            tickSpread: 20,
            twapLength: 5
        }

        await hre.props.coverPoolFactory
          .connect(hre.props.admin)
          .createCoverPool(
            poolParams
        )
        hre.nonce += 1
    }
}
