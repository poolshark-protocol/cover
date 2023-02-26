/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Ticks, TicksInterface } from "../Ticks";

const _abi = [
  {
    inputs: [],
    name: "AmountInDeltaNeutral",
    type: "error",
  },
  {
    inputs: [],
    name: "AmountOutDeltaNeutral",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "InfiniteTickLoop0",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "InfiniteTickLoop1",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidLatestTick",
    type: "error",
  },
  {
    inputs: [],
    name: "LiquidityOverflow",
    type: "error",
  },
  {
    inputs: [],
    name: "NoLiquidityToRollover",
    type: "error",
  },
  {
    inputs: [],
    name: "NotImplementedYet",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickLowerOld",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickLowerRange",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickOrder",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickUpperOld",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickUpperRange",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "bool",
        name: "zeroForOne",
        type: "bool",
      },
      {
        internalType: "uint160",
        name: "priceLimit",
        type: "uint160",
      },
      {
        components: [
          {
            internalType: "uint8",
            name: "unlocked",
            type: "uint8",
          },
          {
            internalType: "int16",
            name: "tickSpread",
            type: "int16",
          },
          {
            internalType: "uint16",
            name: "twapLength",
            type: "uint16",
          },
          {
            internalType: "uint16",
            name: "auctionLength",
            type: "uint16",
          },
          {
            internalType: "int24",
            name: "latestTick",
            type: "int24",
          },
          {
            internalType: "uint32",
            name: "genesisBlock",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "lastBlock",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "auctionStart",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "accumEpoch",
            type: "uint32",
          },
          {
            internalType: "uint128",
            name: "liquidityGlobal",
            type: "uint128",
          },
          {
            internalType: "uint160",
            name: "latestPrice",
            type: "uint160",
          },
          {
            internalType: "contract IRangePool",
            name: "inputPool",
            type: "IRangePool",
          },
        ],
        internalType: "struct ICoverPoolStructs.GlobalState",
        name: "state",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "uint256",
            name: "price",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "liquidity",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "input",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "inputBoosted",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "auctionDepth",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "auctionBoost",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "amountInDelta",
            type: "uint256",
          },
        ],
        internalType: "struct ICoverPoolStructs.SwapCache",
        name: "cache",
        type: "tuple",
      },
    ],
    name: "quote",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "price",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "liquidity",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "input",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "inputBoosted",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "auctionDepth",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "auctionBoost",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "amountInDelta",
            type: "uint256",
          },
        ],
        internalType: "struct ICoverPoolStructs.SwapCache",
        name: "",
        type: "tuple",
      },
      {
        internalType: "uint256",
        name: "amountOut",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x612e1061003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100565760003560e01c80635a9d606f1461005b5780638aa596c6146100c9578063cdb98d07146100f6578063dd3fac9214610116575b600080fd5b61006e610069366004612743565b610138565b6040805183518152602080850151908201528382015191810191909152606080840151908201526080808401519082015260a0808401519082015260c0928301519281019290925260e0820152610100015b60405180910390f35b8180156100d557600080fd5b506100e96100e43660046127f7565b6108ee565b6040516100c09190612838565b81801561010257600080fd5b506100e9610111366004612933565b610f02565b81801561012257600080fd5b506101366101313660046129db565b611bd1565b005b6101786040518060e00160405280600081526020016000815260200160008152602001600081526020016000815260200160008152602001600081525090565b6000856101a95782516001600160a01b03861611158061019757508251155b806101a457506040830151155b6101b8565b82516001600160a01b03861610155b156101c8575081905060006108e5565b6101408401516020850151606086015160808601516001600160a01b0390931692839261ffff90811692169081101561020957876060015161ffff1661020f565b86608001515b61021f90655af3107a4000612a77565b6102299190612aac565b6102339190612a77565b60a08601819052670de0b6b3a76400009061024e9082612ac0565b866040015161025d9190612a77565b6102679190612aac565b606086015287156105c05780876001600160a01b0316111561028f57506001600160a01b0386165b60208501518551604051639026147360e01b815260048101929092526024820183905260448201526000606482018190529073__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af41580156102fd573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103219190612ad8565b9050808660600151116104be576020860151865160608881015192901b9160009173__$1b9fef1800622f5f6a93914ffdeb7ba32f$__91630af8b27f91859161036a9082612a77565b6103749087612ac0565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526044820152606401602060405180830381865af41580156103bd573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103e19190612ad8565b60208901518951604051630724718960e41b815260048101929092526024820183905260448201526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af415801561044f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104739190612ad8565b6001600160a01b0382168952606089015160408a0151919750906104979085612a77565b6104a19190612aac565b6104ab9084612af1565b60c08901525050600060408701526105ba565b80156105ba5760208601518651604051630724718960e41b815260048101929092526024820184905260448201526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af415801561052f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105539190612ad8565b828752606087015160408801519195509061056e9083612a77565b6105789190612aac565b6105829082612af1565b60c08701526060860151604087015161059b9083612a77565b6105a59190612aac565b866040018181516105b69190612af1565b9052505b506108df565b80876001600160a01b031610156105dd57506001600160a01b0386165b60208501518551604051630724718960e41b815260048101929092526024820152604481018290526000606482018190529073__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af415801561064b573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061066f9190612ad8565b9050808660600151116107d6576060860151602087015160405163554d048960e11b81526004810192909252600160601b6024830152604482015260009073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af41580156106e9573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061070d9190612ad8565b87516107199190612ac0565b60208801518851604051639026147360e01b815260048101929092526024820152604481018290526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af4158015610787573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107ab9190612ad8565b818852604088015160608901519196506107c491612af1565b60c088015250600060408701526108dd565b80156108dd5760208601518651604051639026147360e01b815260048101929092526024820152604481018490526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af4158015610847573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061086b9190612ad8565b82875260608701516040880151919550906108869083612a77565b6108909190612aac565b61089a9082612af1565b60c0870152606086015160408701516108b39083612a77565b6108bd9190612aac565b6108c8906001612ac0565b866040018181516108d99190612af1565b9052505b505b84935050505b94509492505050565b6108f66124ce565b815160ff16600003610efa576101608201516040808401519051630d979ec560e11b81526001600160a01b03909216600483015261ffff16602482015273__$657d9a64028a7d57fe1695a914827e9925$__90631b2f3d8a906044016040805180830381865af415801561096e573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906109929190612b08565b60020b608084015260ff16808352600103610efa576020820151608083015160019190910b906109c3908290612b42565b6109cd9190612b7c565b60020b6080830181905260405163986cfba360e01b8152600481019190915273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610a28573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610a4c9190612c09565b6001600160a01b031661014083015260a0820151610a709063ffffffff1643612af1565b63ffffffff1660e083015260016101008301526040805160808101909152620d89e7198082526020820190610aa490612c2d565b60020b815260200183610100015163ffffffff16815260200160006001600160801b0316815250856000846080015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b031602179055509050506040518060800160405280620d89e71960020b8152602001836080015160020b815260200183610100015163ffffffff16815260200160006001600160801b0316815250856000620d89e71960020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b031602179055509050506040518060800160405280836080015160020b8152602001620d89e719610cbb90612c2d565b60020b815261010084015163ffffffff166020820152600060409091018190528690610cea620d89e719612c2d565b60020b815260208082019290925260409081016000208351815485850151938601516060909601516001600160801b0316600160501b026fffffffffffffffffffffffffffffffff60501b1963ffffffff909716660100000000000002969096166601000000000000600160d01b031962ffffff95861663010000000265ffffffffffff19909316959093169490941717169190911792909217909155820151608083015173__$b52f7ddb7db4526c8b5c81c46a9292f776$__9163986cfba391610db89160010b90612c4f565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015610df7573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610e1b9190612c09565b8460020160006101000a8154816001600160a01b0302191690836001600160a01b0316021790555073__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3836020015160010b8460800151610e749190612c97565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015610eb3573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610ed79190612c09565b6002840180546001600160a01b0319166001600160a01b03929092169190911790555b509392505050565b610f0a6124ce565b60016001607f1b036001600160801b0384161115610f3b5760405163581a12d760e11b815260040160405180910390fd5b826001600160801b031688610120015160016001607f1b03610f5d9190612cde565b6001600160801b03161015610f855760405163581a12d760e11b815260040160405180910390fd5b60008a60008860020b60020b81526020019081526020016000206040518060a00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152602001600282016040518060800160405290816000820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152505081525050905060008b60008760020b60020b81526020019081526020016000206040518060a00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152602001600282016040518060800160405290816000820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152505081525050905060008b60008a60020b60020b81526020019081526020016000206040518060800160405290816000820160009054906101000a900460020b60020b60020b81526020016000820160039054906101000a900460020b60020b60020b81526020016000820160069054906101000a900463ffffffff1663ffffffff1663ffffffff16815260200160008201600a9054906101000a90046001600160801b03166001600160801b03166001600160801b031681525050905060008c60008960020b60020b81526020019081526020016000206040518060800160405290816000820160009054906101000a900460020b60020b60020b81526020016000820160039054906101000a900460020b60020b60020b81526020016000820160069054906101000a900463ffffffff1663ffffffff1663ffffffff16815260200160008201600a9054906101000a90046001600160801b03166001600160801b03166001600160801b03168152505090508c60008b60020b60020b815260200190815260200160002060000160009054906101000a900460020b60020b8d60008c60020b60020b815260200190815260200160002060000160039054906101000a900460020b60020b146114f05785156114d35786846000018181516114a89190612d06565b600f0b9052506060820180518891906114c2908390612d4c565b6001600160801b031690525061176e565b86846000018181516114e59190612d77565b600f0b90525061176e565b851561155d576040518060a001604052808861150b90612dbd565b600f0b81526001600160801b03891660208083019190915260006040808401829052606080850183905281516080818101845284825294810184905291820183905281019190915291015293506115ad565b6040805160a081018252600f89900b815260006020808301829052828401829052606080840183905284516080818101875284825292810184905294850183905284019190915281019190915293505b60028b810b600090815260208f9052604090205463010000009004810b9089900b8113156115dc575087611601565b600281900b600090815260208f905260409020805462ffffff191662ffffff8d161790555b8a60020b8c60020b12158061161c57508060020b8b60020b12155b1561163a5760405163044f7fb160e51b815260040160405180910390fd5b60405180608001604052808d60020b81526020018260020b8152602001600063ffffffff16815260200160006001600160801b03168152508e60008d60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b031602179055509050508a8e60008e60020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff160217905550505b600288810b600090815260208f9052604090205463010000008104820b910b146117f25785156117b55786836000018181516117aa9190612d77565b600f0b905250611adb565b86836000018181516117c79190612d06565b600f0b9052506060810180518891906117e1908390612d4c565b6001600160801b0316905250611adb565b851561184c576040805160a081018252600f89900b815260006020808301829052828401829052606080840183905284516080818101875284825292810184905294850183905284019190915281019190915292506118af565b6040518060a001604052808861186190612dbd565b600f0b81526001600160801b03891660208083019190915260006040808401829052606080850183905281516080818101845284825294810184905291820183905281019190915291015292505b600289810b600090815260208f90526040902054810b908b900b8112156118d35750895b8d60008b60020b60020b815260200190815260200160002060000160009054906101000a900460020b60020b8e60008c60020b60020b815260200190815260200160002060000160039054906101000a900460020b60020b148061193d57508860020b8a60020b13155b8061194e57508060020b8960020b13155b1561196c576040516329f7012160e21b815260040160405180910390fd5b60405180608001604052808260020b81526020018b60020b8152602001600063ffffffff16815260200160006001600160801b03168152508e60008b60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b03160217905550905050888e60008360020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff160217905550888e60008c60020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff160217905550505b5050600288810b600090815260208e815260408083208651838801516001600160801b03908116600160801b908102928216929092178355838901516060808b0151831684029183169190911760018086019190915560809a8b01518051818901518516860290851617868b0155808701519083015184168502908416176003958601558e890b88529685902089518a88015184168502908416178155898601518a83015184168502908416179781019790975597909801518051948101518916820294891694909417958501959095559082015191909401518516909202919093161791015550869998505050505050505050565b600286810b600081815260208c81526040808320815160a0810183528154600f81900b82526001600160801b03600160801b918290048116838701526001840154808216848701528290048116606080850191909152855160808181018852868c015480851683528590048416828a01526003909601548084168289015293909304821683820152848401929092529686528f855294839020835192830184525480880b83526301000000810490970b9382019390935263ffffffff660100000000000087041691810191909152600160501b90940490921690830152908315611d15578415611cf8578582600001818151611ccd9190612d77565b600f0b905250606081018051879190611ce7908390612cde565b6001600160801b0316905250611d3a565b8582600001818151611d0a9190612d06565b600f0b905250611d3a565b8415611d3a578582602001818151611d2d9190612cde565b6001600160801b03169052505b818b60008a60020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160008201518160000160006101000a8154816001600160801b0302191690836001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b031602179055505050905050808a60008a60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b03160217905550905050505060008960008760020b60020b81526020019081526020016000206040518060a00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152602001600282016040518060800160405290816000820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b03168152505081525050905060008960008860020b60020b81526020019081526020016000206040518060800160405290816000820160009054906101000a900460020b60020b60020b81526020016000820160039054906101000a900460020b60020b60020b81526020016000820160069054906101000a900463ffffffff1663ffffffff1663ffffffff16815260200160008201600a9054906101000a90046001600160801b03166001600160801b03166001600160801b0316815250509050821561224b57841561220e5785826000018181516122039190612d06565b600f0b90525061226f565b85826000018181516122209190612d77565b600f0b90525060608101805187919061223a908390612cde565b6001600160801b031690525061226f565b8461226f5785826020018181516122629190612cde565b6001600160801b03169052505b818b60008960020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160008201518160000160006101000a8154816001600160801b0302191690836001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b031602179055505050905050808a60008960020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550606082015181600001600a6101000a8154816001600160801b0302191690836001600160801b031602179055509050505050505050505050505050565b6040805161018081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e0810182905261010081018290526101208101829052610140810182905261016081019190915290565b8035801515811461254257600080fd5b919050565b6001600160a01b038116811461255c57600080fd5b50565b803561254281612547565b604051610180810167ffffffffffffffff8111828210171561259c57634e487b7160e01b600052604160045260246000fd5b60405290565b60405160e0810167ffffffffffffffff8111828210171561259c57634e487b7160e01b600052604160045260246000fd5b60ff8116811461255c57600080fd5b8035612542816125d3565b8035600181900b811461254257600080fd5b803561ffff8116811461254257600080fd5b8060020b811461255c57600080fd5b803561254281612611565b803563ffffffff8116811461254257600080fd5b80356001600160801b038116811461254257600080fd5b6000610180828403121561266957600080fd5b61267161256a565b905061267c826125e2565b815261268a602083016125ed565b602082015261269b604083016125ff565b60408201526126ac606083016125ff565b60608201526126bd60808301612620565b60808201526126ce60a0830161262b565b60a08201526126df60c0830161262b565b60c08201526126f060e0830161262b565b60e082015261010061270381840161262b565b9082015261012061271583820161263f565b9082015261014061272783820161255f565b9082015261016061273983820161255f565b9082015292915050565b6000806000808486036102a081121561275b57600080fd5b61276486612532565b9450602086013561277481612547565b93506127838760408801612656565b925060e06101bf198201121561279857600080fd5b506127a16125a2565b6101c086013581526101e0860135602082015261020086013560408201526102208601356060820152610240860135608082015261026086013560a08201526102809095013560c0860152509194909350909190565b6000806000806101e0858703121561280e57600080fd5b84359350602085013592506040850135915061282d8660608701612656565b905092959194509250565b815160ff16815261018081016020830151612858602084018260010b9052565b50604083015161286e604084018261ffff169052565b506060830151612884606084018261ffff169052565b506080830151612899608084018260020b9052565b5060a08301516128b160a084018263ffffffff169052565b5060c08301516128c960c084018263ffffffff169052565b5060e08301516128e160e084018263ffffffff169052565b506101008381015163ffffffff1690830152610120808401516001600160801b031690830152610140808401516001600160a01b03908116918401919091526101609384015116929091019190915290565b60008060008060008060008060006102808a8c03121561295257600080fd5b8935985060208a0135975061296a8b60408c01612656565b96506101c08a013561297b81612611565b95506101e08a013561298c81612611565b94506102008a013561299d81612611565b93506102208a01356129ae81612611565b92506129bd6102408b0161263f565b91506129cc6102608b01612532565b90509295985092959850929598565b60008060008060008060008060006102808a8c0312156129fa57600080fd5b8935985060208a01359750612a128b60408c01612656565b96506101c08a0135612a2381612611565b95506101e08a0135612a3481612611565b9450612a436102008b0161263f565b9350612a526102208b01612532565b92506129bd6102408b01612532565b634e487b7160e01b600052601160045260246000fd5b6000816000190483118215151615612a9157612a91612a61565b500290565b634e487b7160e01b600052601260045260246000fd5b600082612abb57612abb612a96565b500490565b60008219821115612ad357612ad3612a61565b500190565b600060208284031215612aea57600080fd5b5051919050565b600082821015612b0357612b03612a61565b500390565b60008060408385031215612b1b57600080fd5b8251612b26816125d3565b6020840151909250612b3781612611565b809150509250929050565b60008160020b8360020b80612b5957612b59612a96565b627fffff19821460001982141615612b7357612b73612a61565b90059392505050565b60008160020b8360020b627fffff600082136000841383830485118282161615612ba857612ba8612a61565b627fffff196000851282811687830587121615612bc757612bc7612a61565b60008712925085820587128484161615612be357612be3612a61565b85850587128184161615612bf957612bf9612a61565b5050509290910295945050505050565b600060208284031215612c1b57600080fd5b8151612c2681612547565b9392505050565b60008160020b627fffff198103612c4657612c46612a61565b60000392915050565b60008160020b8360020b6000811281627fffff1901831281151615612c7657612c76612a61565b81627fffff018313811615612c8d57612c8d612a61565b5090039392505050565b60008160020b8360020b6000821282627fffff03821381151615612cbd57612cbd612a61565b82627fffff19038212811615612cd557612cd5612a61565b50019392505050565b60006001600160801b0383811690831681811015612cfe57612cfe612a61565b039392505050565b600081600f0b83600f0b600081128160016001607f1b031901831281151615612d3157612d31612a61565b8160016001607f1b03018313811615612c8d57612c8d612a61565b60006001600160801b03808316818516808303821115612d6e57612d6e612a61565b01949350505050565b600081600f0b83600f0b600082128260016001607f1b0303821381151615612da157612da1612a61565b8260016001607f1b0319038212811615612cd557612cd5612a61565b600081600f0b60016001607f1b03198103612c4657612c46612a6156fea2646970667358221220f518f9f614988ef87fd1914bd3916f4d35c3776c16426ade94f97130c58a814d64736f6c634300080d0033";

type TicksConstructorParams =
  | [linkLibraryAddresses: TicksLibraryAddresses, signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TicksConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => {
  return (
    typeof xs[0] === "string" ||
    (Array.isArray as (arg: any) => arg is readonly any[])(xs[0]) ||
    "_isInterface" in xs[0]
  );
};

export class Ticks__factory extends ContractFactory {
  constructor(...args: TicksConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      const [linkLibraryAddresses, signer] = args;
      super(_abi, Ticks__factory.linkBytecode(linkLibraryAddresses), signer);
    }
  }

  static linkBytecode(linkLibraryAddresses: TicksLibraryAddresses): string {
    let linkedBytecode = _bytecode;

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$357eccfa53a4e88c122661903e0e603301\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/DyDxMath.sol:DyDxMath"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$1b9fef1800622f5f6a93914ffdeb7ba32f\\$__", "g"),
      linkLibraryAddresses[
        "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"
      ]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$657d9a64028a7d57fe1695a914827e9925\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/TwapOracle.sol:TwapOracle"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$b52f7ddb7db4526c8b5c81c46a9292f776\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/TickMath.sol:TickMath"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    return linkedBytecode;
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<Ticks> {
    return super.deploy(overrides || {}) as Promise<Ticks>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): Ticks {
    return super.attach(address) as Ticks;
  }
  connect(signer: Signer): Ticks__factory {
    return super.connect(signer) as Ticks__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TicksInterface {
    return new utils.Interface(_abi) as TicksInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Ticks {
    return new Contract(address, _abi, signerOrProvider) as Ticks;
  }
}

export interface TicksLibraryAddresses {
  ["contracts/libraries/DyDxMath.sol:DyDxMath"]: string;
  ["contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"]: string;
  ["contracts/libraries/TwapOracle.sol:TwapOracle"]: string;
  ["contracts/libraries/TickMath.sol:TickMath"]: string;
}
