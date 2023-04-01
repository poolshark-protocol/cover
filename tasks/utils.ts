import { readFileSync, writeFileSync } from 'fs'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { ERC20_ABI } from '../test/utils/constants'
import '@nomiclabs/hardhat-ethers'

export async function getWalletAddress(
    hre: HardhatRuntimeEnvironment,
    privateKey: string
): Promise<string> {
    return new hre.ethers.Wallet(privateKey !== undefined ? privateKey : '').address
}

export async function getNonce(
    hre: HardhatRuntimeEnvironment,
    accountAddress: string
): Promise<number> {
    return await hre.ethers.provider.getTransactionCount(accountAddress)
}

export async function readConfigFile(chainName: string, configName: string): Promise<string> {
    const deploymentsStr = readFileSync('./tasks/deploy/config.json', 'utf-8')
    const deployments = JSON.parse(deploymentsStr)
    return deployments[chainName][configName]
}

export async function readDeploymentsFile(
    contractName: string,
    chainId: number | undefined
): Promise<string> {
    if (chainId === undefined) {
        throw new Error('ERROR: undefined chainId in hardhat.config.ts')
    }
    const deploymentsStr = readFileSync('./scripts/autogen/contract-deployments.json', 'utf-8')
    const deployments = JSON.parse(deploymentsStr)
    if (deployments[hre.network.name][contractName] == undefined) {
        return ''
    }
    return deployments[hre.network.name][contractName].address
}

export async function writeDeploymentsFile(
    contractName: string,
    contractAddress: string,
    chainId: number | undefined
): Promise<boolean> {
    if (chainId === undefined) {
        throw new Error('ERROR: undefined chainId in hardhat.config.ts')
    }
    let deploymentsStr = readFileSync('./tasks/deploy/deployments.json', 'utf-8')
    const deployments = JSON.parse(deploymentsStr)
    if (!Object.prototype.hasOwnProperty.call(deployments, chainId)) {
        console.log(deployments)
        deployments[chainId] = {}
        console.log(deployments[chainId])
    }
    deployments[chainId][contractName] = {
        address: contractAddress,
        created: new Date(),
    }
    deploymentsStr = JSON.stringify(deployments, null, 4)
    writeFileSync('./tasks/deploy/deployments.json', deploymentsStr)
    return true
}
