/* eslint-disable */
import { BigInt, BigDecimal, Address } from '@graphprotocol/graph-ts'
import { CoverPoolFactory as FactoryContract } from '../../generated/CoverPoolFactory/CoverPoolFactory'
export let FACTORY_ADDRESS = '0xd1f805fb8206ffe1b76e16c002a34739be66f977'
export let WETH_ADDRESS = '0x5f251b03c65400c98db9d4082a5700576199d325'

// tokens where USD value is safe to use for globals
export let WHITELIST_TOKENS: string[] = [
  '0x5f251b03c65400c98db9d4082a5700576199d325', //WETH
  '0x30dd8f91cb7da085e43f04b8033dcf0c2856a27c', //DAI
]

// used for safe eth pricing 
export let STABLE_COINS: string[] = [
  '0x30dd8f91cb7da085e43f04b8033dcf0c2856a27c', //DAI
]

// used for safe eth pricing 
export const STABLE_POOL_ADDRESS = '0x2c90a958479b6385bf7fe768c6817f2b67e28af5'

// determines which token to use for eth<-> rate, true means stable is token0 in pool above 
export const STABLE_IS_TOKEN_0 = false

// minimum eth required in pool to count usd values towards global prices 
export let MINIMUM_ETH_LOCKED = BigDecimal.fromString('0')

// pool that breaks with subgraph logic 
export const ERROR_POOL = '0x0000000000000000000000000000000000000000'

export let ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

export let ZERO_BI = BigInt.fromI32(0)
export let ONE_BI = BigInt.fromI32(1)
export let ZERO_BD = BigDecimal.fromString('0')
export let ONE_BD = BigDecimal.fromString('1')
export let TWO_BD = BigDecimal.fromString('2')
export let BI_18 = BigInt.fromI32(18)

export let factoryContract = FactoryContract.bind(Address.fromString(FACTORY_ADDRESS))

