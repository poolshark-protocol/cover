/* eslint-disable */
import { BigInt, BigDecimal, Address } from '@graphprotocol/graph-ts'
import { CoverPoolFactory as FactoryContract } from '../../generated/CoverPoolFactory/CoverPoolFactory'
export let FACTORY_ADDRESS = '0x6b83e41BB067EFaF88aa6F83cc5c1D21d0a14714'
export let WETH_ADDRESS = '0x6774be1a283faed7ed8e40463c40fb33a8da3461'

// tokens where USD value is safe to use for globals
export let WHITELIST_TOKENS: string[] = [
  '0x6774be1a283faed7ed8e40463c40fb33a8da3461', //WETH
  '0xc26906e10e8bdadeb2cf297eb56df59775ee52c4', //USDC
]

// used for safe eth pricing 
export let STABLE_COINS: string[] = [
  '0xc26906e10e8bdadeb2cf297eb56df59775ee52c4', //USDC
]

// used for safe eth pricing 
export const STABLE_POOL_ADDRESS = '0x7c745bc99b7c17de1666a54e9b551fc2933d83e1'

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

