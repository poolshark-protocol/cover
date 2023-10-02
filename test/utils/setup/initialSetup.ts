import { SUPPORTED_NETWORKS } from '../../../scripts/constants/supportedNetworks'
import { DeployAssist } from '../../../scripts/util/deployAssist'
import { ContractDeploymentsKeys } from '../../../scripts/util/files/contractDeploymentKeys'
import { ContractDeploymentsJson } from '../../../scripts/util/files/contractDeploymentsJson'
import { CoverPool__factory, PoolsharkLimitSource__factory, PoolsharkRouter__factory, PositionERC1155__factory, QuoteCall__factory, Token20Batcher__factory } from '../../../typechain'
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
    private poolsharkString = ethers.utils.formatBytes32String('PSHARK-CPROD')
    private constantProductString =  ethers.utils.formatBytes32String('CONSTANT-PRODUCT')
    private deployAssist: DeployAssist
    private contractDeploymentsJson: ContractDeploymentsJson
    private contractDeploymentsKeys: ContractDeploymentsKeys

    /// DEPLOY CONFIG
    private deployRouter = false
    private deployTokens = false
    private deployPools = true
    private deployContracts = true
    private deployPoolsharkLimitSource = true
    private deployUniswapV3Source = false

    constructor() {
        this.deployAssist = new DeployAssist()
        this.contractDeploymentsJson = new ContractDeploymentsJson()
        this.contractDeploymentsKeys = new ContractDeploymentsKeys()
    }

    public async initialCoverPoolSetup(): Promise<number> {

        const network = SUPPORTED_NETWORKS[hre.network.name.toUpperCase()]

        if (!this.deployTokens && hre.network.name != 'hardhat') {
        
            const token0Address = (
                await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                    {
                        networkName: hre.network.name,
                        objectName: 'token0',
                    },
                    'initialSetup'
                    )
            ).contractAddress
            const token1Address = (
                await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'token1',
                },
                'initialSetup'
                )
            ).contractAddress
            hre.props.token0 = await hre.ethers.getContractAt('Token20', token0Address)
            hre.props.token1 = await hre.ethers.getContractAt('Token20', token1Address)
        } else {
            await this.deployAssist.deployContractWithRetry(
                network,
                // @ts-ignore
                Token20Batcher__factory,
                'token20Batcher',
                []
            )

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
        }

        if (hre.network.name == 'hardhat') {
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
            await hre.props.uniswapV3PoolMock.setObservationCardinality('4', '4')

            hre.nonce += 1;
        } else if (this.deployPoolsharkLimitSource) {
            const limitPoolFactoryAddress = (
                await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                    {
                        networkName: hre.network.name,
                        objectName: 'limitPoolFactory',
                    },
                    'initialSetup'
                    )
            ).contractAddress

            const limitPoolManagerAddress = (
                await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                    {
                        networkName: hre.network.name,
                        objectName: 'limitPoolManager',
                    },
                    'initialSetup'
                    )
            ).contractAddress

            await this.deployAssist.deployContractWithRetry(
                network,
                // @ts-ignore
                PoolsharkLimitSource__factory,
                'poolsharkLimitSource',
                [
                    limitPoolFactoryAddress,
                    limitPoolManagerAddress,
                    this.constantProductString
                ]
            )
        } else if (this.deployUniswapV3Source) {
            const uniswapV3FactoryAddress = (
                await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                    {
                        networkName: hre.network.name,
                        objectName: 'uniswapV3Factory',
                    },
                    'initialSetup'
                    )
            ).contractAddress

            await this.deployAssist.deployContractWithRetry(
                network,
                // @ts-ignore
                UniswapV3Source__factory,
                'uniswapV3Source',
                [
                    uniswapV3FactoryAddress
                ]
            )
        }

        if (this.deployContracts || hre.network.name == 'hardhat') {
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
                    'contracts/libraries/Deltas.sol:Deltas': hre.props.deltasLib.address,
                    'contracts/libraries/TickMap.sol:TickMap': hre.props.tickMapLib.address,
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

            const setFactoryTxn = await hre.props.coverPoolManager.setFactory(
                hre.props.coverPoolFactory.address
            )
            await setFactoryTxn.wait()
    
            hre.nonce += 1
    
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
                    'contracts/libraries/Positions.sol:Positions': hre.props.positionsLib.address
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

            if (hre.network.name == 'hardhat' || this.deployUniswapV3Source) {
                const enableImplTxn = await hre.props.coverPoolManager.enablePoolType(
                    this.uniV3String,
                    hre.props.coverPoolImpl.address,
                    hre.props.positionERC1155.address,
                    hre.props.uniswapV3Source.address
                )
                await enableImplTxn.wait();
                hre.nonce += 1;
            } else if (this.deployPoolsharkLimitSource) {
                const enableImplTxn = await hre.props.coverPoolManager.enablePoolType(
                    this.poolsharkString,
                    hre.props.coverPoolImpl.address,
                    hre.props.positionERC1155.address,
                    hre.props.poolsharkLimitSource.address
                )
                await enableImplTxn.wait();
                hre.nonce += 1;
                console.log('impl enabled')
            }
        }

        if (this.deployRouter || hre.network.name == 'hardhat') {
            await this.deployAssist.deployContractWithRetry(
                network,
                //@ts-ignore
                PoolsharkRouter__factory,
                'poolRouter',
                [
                  '0xbd6d010bcecc7440a72889546411e0edbb333ea2',  // limitPoolFactory
                  hre.props.coverPoolFactory.address
                ]
            )
        }

        let coverPoolAddress; let coverPoolTokenAddress;

        if (this.deployPools && hre.network.name != 'hardhat') {
            let poolParams1: CoverPoolParams;
            if (this.deployPoolsharkLimitSource) {
                // ENABLE VOL TIER 1
                console.log('vol tier 1')
                const volTier1: VolatilityTier = {
                    minAmountPerAuction: BN_ZERO,
                    auctionLength: 12,
                    sampleInterval: 1000,
                    syncFee: 0,
                    fillFee: 0,
                    minPositionWidth: 1,
                    minAmountLowerPriced: true
                }

                const enableVolTier1 = await hre.props.coverPoolManager.enableVolatilityTier(
                    this.poolsharkString,
                    1000, // feeTier
                    20,  // tickSpread
                    12,   // twapLength (seconds) = ~40 arbitrum blocks
                    volTier1
                )
                await enableVolTier1.wait();
        
                hre.nonce += 1;
                console.log('pool 1')

                // CREATE POOL 1
                poolParams1 = {
                    poolType: this.poolsharkString,
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: 1000,
                    tickSpread: 20,
                    twapLength: 12
                }
                let createPoolTxn = await hre.props.coverPoolFactory.createCoverPool(
                    poolParams1
                )
                await createPoolTxn.wait();

                hre.nonce += 1;

                // CREATE VOL TIER 2
                console.log('vol tier 2')
                const volTier2: VolatilityTier = {
                    minAmountPerAuction: BN_ZERO,
                    auctionLength: 12,
                    sampleInterval: 1000,
                    syncFee: 0,
                    fillFee: 0,
                    minPositionWidth: 1,
                    minAmountLowerPriced: true
                }

                const enableVolTier2 = await hre.props.coverPoolManager.enableVolatilityTier(
                    this.poolsharkString,
                    3000, // feeTier
                    60,   // tickSpread
                    12,   // twapLength (seconds) = ~40 arbitrum blocks
                    volTier2
                )
                await enableVolTier2.wait();
        
                hre.nonce += 1;

                // CREATE POOL 2
                console.log('pool 2')
                const poolParams2: CoverPoolParams = {
                    poolType: this.poolsharkString,
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: 3000,
                    tickSpread: 60,
                    twapLength: 12
                }
                let createPoolTxn2 = await hre.props.coverPoolFactory.createCoverPool(
                    poolParams2
                )
                await createPoolTxn2.wait();

                hre.nonce += 1;

                // CREATE VOL TIER 3
                console.log('vol tier 3')
                const volTier3: VolatilityTier = {
                    minAmountPerAuction: BN_ZERO,
                    auctionLength: 5,
                    sampleInterval: 1000,
                    syncFee: 0,
                    fillFee: 0,
                    minPositionWidth: 1,
                    minAmountLowerPriced: true
                }

                const enableVolTier3 = await hre.props.coverPoolManager.enableVolatilityTier(
                    this.poolsharkString,
                    10000, // feeTier
                    200,  // tickSpread
                    12,   // twapLength (seconds) = ~40 arbitrum blocks
                    volTier3
                )
                await enableVolTier3.wait();
        
                hre.nonce += 1;

                // CREATE POOL 3
                console.log('pool 3')
                const poolParams3: CoverPoolParams = {
                    poolType: this.poolsharkString,
                    tokenIn: hre.props.token0.address,
                    tokenOut: hre.props.token1.address,
                    feeTier: 10000,
                    tickSpread: 200,
                    twapLength: 12
                }
                let createPoolTxn3 = await hre.props.coverPoolFactory.createCoverPool(
                    poolParams3
                )
                await createPoolTxn3.wait();

                hre.nonce += 1;
            }

            [coverPoolAddress, coverPoolTokenAddress] = await hre.props.coverPoolFactory.getCoverPool(
                poolParams1
            );
        } else if (hre.network.name == 'hardhat') {
            const volTier1: VolatilityTier = {
                minAmountPerAuction: BN_ZERO,
                auctionLength: 5,
                sampleInterval: 1000,
                syncFee: 0,
                fillFee: 0,
                minPositionWidth: 1,
                minAmountLowerPriced: true
            }
    
            const enableVolTier1 = await hre.props.coverPoolManager.enableVolatilityTier(
                this.uniV3String,
                500, // feeTier
                20,  // tickSpread
                5,   // twapLength (seconds)
                volTier1
            )
            await enableVolTier1.wait();
    
            hre.nonce += 1;
    
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
            await createPoolTxn.wait();
    
            hre.nonce += 1;

            [coverPoolAddress, coverPoolTokenAddress] = await hre.props.coverPoolFactory.getCoverPool(
                poolParams1
            );
        }
        if (this.deployPools || hre.network.name == 'hardhat') {
            hre.props.coverPool = await hre.ethers.getContractAt('CoverPool', coverPoolAddress)
            hre.props.coverPoolToken = await hre.ethers.getContractAt('PositionERC1155', coverPoolTokenAddress)
    
            await this.deployAssist.saveContractDeployment(
                network,
                'CoverPool',
                'coverPool',
                hre.props.coverPool,
                []
            )
        }
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
        const poolsharkRouterAddress = (
            await this.contractDeploymentsJson.readContractDeploymentsJsonFile(
                {
                    networkName: hre.network.name,
                    objectName: 'poolRouter',
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
        hre.props.poolRouter = await hre.ethers.getContractAt('PoolsharkRouter', poolsharkRouterAddress)

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
