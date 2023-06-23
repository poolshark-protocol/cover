import * as dotenv from 'dotenv'
import { Contract } from 'ethers'
import { HardhatUserConfig, task } from 'hardhat/config'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
require('solidity-coverage')
require('hardhat-contract-sizer')
import { handleHardhatTasks } from './taskHandler'

handleHardhatTasks()
dotenv.config()
const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.13',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        goerli: {
            chainId: 5,
            gasPrice: 50000000000,
            url: process.env.GOERLI_URL || '',
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            timeout: 60000,
            allowUnlimitedContractSize: true,
        },
        arb_goerli: {
            chainId: 421613,
            gasPrice: 100000000000,
            url: process.env.ARBITRUM_GOERLI_URL || '',
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            timeout: 60000,
            allowUnlimitedContractSize: true,
        },
        scroll_alpha: {
            chainId: 534353,
            gasPrice: 4000000,
            url: process.env.SCROLL_ALPHA_URL || '',
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            timeout: 60000,
            allowUnlimitedContractSize: true,
        },
        op_goerli: {
            chainId: 420,
            gasPrice: 500,
            url: process.env.SCROLL_ALPHA_URL || '',
            accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
            timeout: 60000,
            allowUnlimitedContractSize: true,
        },
    },
    etherscan: { 
        apiKey: {
            arbitrumGoerli: process.env.ARBITRUM_GOERLI_API_KEY,
            scrollAlpha: 'abc',
        },
        customChains: [
            {
              network: 'scroll_alpha',
              chainId: 534353,
              urls: {
                apiURL: 'https://blockscout.scroll.io/api',
                browserURL: 'https://blockscout.scroll.io/',
              },
            },
        ],
    },
}
export default config
