# 🦈 Poolshark Cover Contracts 🦈
A liquidity pool to protect against directional risk and easily exit positions.

An implementation of Cover, a stop-loss liquidity pool, written in Solidity. 

This follows the specification detailed in the [Poolshark whitepaper](https://docs.poolsharks.io/whitepaper/).

### What's New 
Pretty much everything. There's a lot of math around `amountDeltaMax`.

This is the expected token amount to be received over a position's price range.

Since the stop-loss unlocks in the opposite direction of how swaps move the price, the logic in `Claims.sol` gets a bit deep.

Most of the intense logic pieces are in `Claims.sol` and `Epochs.sol`.

Almost all of the bytecode deals with in-memory calculations, making gas costs as scalable as its AMMs predecessors. 

### Installation
```
git clone https://github.com/poolshark-protocol/cover
cd cover
yarn install
```

This repo makes full use of Echidna's assertion testing to fully test and analyze the Cover smart contracts.

### Testing
Tests can be run via the following commands.

Only Hardhat is supported for now, with Foundry support soon to follow.
```
yarn clean
yarn compile
yarn test
```

Contracts can be deployed onto Arbitrum Goerli using the deploy script:
```
npx hardhat deploy-coverpools --network arb_goerli
```

### Contracts
#### Cover Pool
Cover Pool is the liquidity pool contract which contains all the calls for the pool. Outside of the liquidity unlock and claim processes, it is a relatively simple AMM liquidity pool which uses a TWAP source to unlock liquidity and fill user's stop-loss positions via 'Auctions'. Positions are implemented via an ERC-1155 for transferability and composability.
<br/><br/>
The contracts are implemented with extremely limited admin functionality, namely modifying fees up to a defined ceiling of 1% and adding new volatility tiers.
<br/><br/>
Cover Pools utilize epochs to determine to what tick in the user's position range they have been filled. A `fillFee` can be turned on by the protocol if desired, taking a portion of any filled positions amounts and directing that to a chosen `feeTo` address. If ever a pool were to ever require an extensive sync, a user burning a position could simply skip the syncing process by passing `sync = true`.

#### Supported Interfaces
_ERC-165: Standard Interface Detection_

_ERC-1155: Multi Token Standard_

#### Cover Pool Factory
The factory which handles the deployment of new Cover Pools. The factory works by cloning the implementation contract to match a given Cover pool type. Each pool type, which is ultimately in control of the Protocol-Owned liquidity each pair accrues. This will then be used for future Tinkermaster expansion. The deployment of new pools is pausable through a EOA controled timelock.

##### Supported Interfaces
_ERC-1167: Minimal Proxy Contract_

#### Supported Protocols
To allow the most flexible deployment of Cover Pools, this repo prepares several integrations in mind, primarily for Uniswap V3 TWAP and Poolshark Limit TWAP.

### Testing Design
#### Coverage
ERC-1155 Functions

totalSupply
balanceOf
transfer
transferFrom
approve
allowance

General Functions

mint
burn
swap
quote
snapshot
immutables
priceBounds

![image](https://github.com/poolshark-protocol/cover/assets/84204260/60ee98e1-1bf6-48c8-8119-10c528a6ce5a)
