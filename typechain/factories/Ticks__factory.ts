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
            internalType: "uint16",
            name: "swapFee",
            type: "uint16",
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
            name: "feeAmount",
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
            name: "feeAmount",
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
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x61321461003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100565760003560e01c80635a9d606f1461005b5780638aa596c6146100e1578063cdb98d071461010e578063dd3fac921461012e575b600080fd5b61006e610069366004612b2a565b610150565b6040516100d8929190600061012082019050835182526020840151602083015260408401516040830152606084015160608301526080840151608083015260a084015160a083015260c084015160c083015260e084015160e0830152826101008301529392505050565b60405180910390f35b8180156100ed57600080fd5b506101016100fc366004612bea565b610b0e565b6040516100d89190612c2b565b81801561011a57600080fd5b50610101610129366004612d37565b61106f565b81801561013a57600080fd5b5061014e610149366004612ddf565b611c3a565b005b61019860405180610100016040528060008152602001600081526020016000815260200160008152602001600081526020016000815260200160008152602001600081525090565b6000856101bc5782516001600160a01b0386161115806101b757508251155b6101cb565b82516001600160a01b03861610155b156101db57508190506000610b05565b6101608401516040850151608086015160a08601516001600160a01b0390931692839261ffff90811692169081101561021c57876080015161ffff16610222565b8660a001515b61023290655af3107a4000612e7b565b61023c9190612eb0565b6102469190612e7b565b60c08601819052670de0b6b3a7640000906102619082612ec4565b86606001516102709190612e7b565b61027a9190612eb0565b608086015287156106e057866001600160a01b03168110156102a257506001600160a01b0386165b60208501518551604051630e8e499360e21b8152600481019290925260248201839052604482015260009073__$357eccfa53a4e88c122661903e0e603301$__90633a39264c90606401602060405180830381865af4158015610309573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061032d9190612edc565b9050808660800151116105555760208601518651608088015160609290921b9160009173__$1b9fef1800622f5f6a93914ffdeb7ba32f$__91630af8b27f9185916103789082612e7b565b6103829087612ec4565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526044820152606401602060405180830381865af41580156103cb573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103ef9190612edc565b60208901518951604051630b00d01b60e31b8152600481019290925260248201839052604482015290915073__$357eccfa53a4e88c122661903e0e603301$__9063580680d890606401602060405180830381865af4158015610456573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061047a9190612edc565b6001600160a01b0382168952608089015160608a015191975073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9163aa9a091291906104ba9087612e7b565b6104c49190612eb0565b6104ce9086612ef5565b60208b01516040516001600160e01b031960e085901b1681526004810192909252600160601b60248301526044820152606401602060405180830381865af415801561051e573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105429190612edc565b60e08901525050600060608701526106da565b80156106da5760208601518651604051630b00d01b60e31b8152600481019290925260248201849052604482015273__$357eccfa53a4e88c122661903e0e603301$__9063580680d890606401602060405180830381865af41580156105bf573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105e39190612edc565b8287526080870151606088015191955073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9163aa9a0912919061061a9085612e7b565b6106249190612eb0565b61062e9084612ef5565b60208901516040516001600160e01b031960e085901b1681526004810192909252600160601b60248301526044820152606401602060405180830381865af415801561067e573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906106a29190612edc565b60e0870152608086015160608701516106bb9083612e7b565b6106c59190612eb0565b866060018181516106d69190612ef5565b9052505b50610aff565b866001600160a01b03168111156106fd57506001600160a01b0386165b60208501518551604051630b00d01b60e31b8152600481019290925260248201526044810183905260009073__$357eccfa53a4e88c122661903e0e603301$__9063580680d890606401602060405180830381865af4158015610764573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107889190612edc565b905080866080015111610978576080860151602087015160405163554d048960e11b81526004810192909252600160601b6024830152604482015260009073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015610802573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108269190612edc565b87516108329190612ec4565b60208801518851604051630e8e499360e21b8152600481019290925260248201526044810182905290915073__$357eccfa53a4e88c122661903e0e603301$__90633a39264c90606401602060405180830381865af4158015610899573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108bd9190612edc565b8188526060880151608089015191965073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9163aa9a0912916108f291612ef5565b60208a01516040516001600160e01b031960e085901b1681526004810192909252600160601b60248301526044820152606401602060405180830381865af4158015610942573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906109669190612edc565b60e08801525060006060870152610afd565b8015610afd5760208601518651604051630e8e499360e21b8152600481019290925260248201526044810184905273__$357eccfa53a4e88c122661903e0e603301$__90633a39264c90606401602060405180830381865af41580156109e2573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610a069190612edc565b8287526080870151606088015191955073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9163aa9a09129190610a3d9085612e7b565b610a479190612eb0565b610a519084612ef5565b60208901516040516001600160e01b031960e085901b1681526004810192909252600160601b60248301526044820152606401602060405180830381865af4158015610aa1573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610ac59190612edc565b60e087015260808601516060870151610ade9083612e7b565b610ae89190612eb0565b86606001818151610af99190612ef5565b9052505b505b84935050505b94509492505050565b610b1661289c565b815160ff16600003611067576101808201516060830151604051630d979ec560e11b81526001600160a01b03909216600483015261ffff16602482015273__$657d9a64028a7d57fe1695a914827e9925$__90631b2f3d8a906044016040805180830381865af4158015610b8e573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610bb29190612f0c565b60020b60a084015260ff1680835260010361106757604082015160a083015160019190910b90610be3908290612f46565b610bed9190612f80565b60020b60a0830181905260405163986cfba360e01b8152600481019190915273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610c48573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610c6c919061300d565b6001600160a01b031661016083015260c0820151610c909063ffffffff1643612ef5565b63ffffffff1661010083015260016101208301526040805160608101909152620d89e7198082526020820190610cc590613031565b60020b815260200183610120015163ffffffff168152508560008460a0015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff1602179055509050506040518060600160405280620d89e71960020b81526020018360a0015160020b815260200183610120015163ffffffff16815250856000620d89e71960020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff16021790555090505060405180606001604052808360a0015160020b8152602001620d89e719610e6290613031565b60020b815261012084015163ffffffff16602090910152856000610e89620d89e719613031565b60020b8152602080820192909252604090810160002083518154938501519483015163ffffffff1666010000000000000269ffffffff0000000000001962ffffff96871663010000000265ffffffffffff199096169690921695909517939093179290921692909217905582015160a083015173__$b52f7ddb7db4526c8b5c81c46a9292f776$__9163986cfba391610f259160010b90613053565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015610f64573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610f88919061300d565b8460010160006101000a8154816001600160a01b0302191690836001600160a01b0316021790555073__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3836040015160010b8460a00151610fe1919061309b565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015611020573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611044919061300d565b6001840180546001600160a01b0319166001600160a01b03929092169190911790555b509392505050565b61107761289c565b60016001607f1b036001600160801b03841611156110a85760405163581a12d760e11b815260040160405180910390fd5b826001600160801b031688610140015160016001607f1b036110ca91906130e2565b6001600160801b031610156110f25760405163581a12d760e11b815260040160405180910390fd5b60008a60008860020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b031681525050905060008b60008760020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b03168152505090508a60008960020b60020b815260200190815260200160002060000160009054906101000a900460020b60020b8b60008a60020b60020b815260200190815260200160002060000160039054906101000a900460020b60020b1461147757831561144e578482600001818151611423919061310a565b600f0b90525060208201805186919061143d908390613150565b6001600160801b0316905250611695565b6114588286612262565b9150848260000181815161146c919061317b565b600f0b905250611695565b83156114d1576040518060e0016040528086611492906131c1565b600f0b81526001600160801b0387166020820152600060408201819052606082018190526080820181905260a0820181905260c0909101529150611511565b6040805160e081018252600f87900b8152600060208201819052918101829052606081018290526080810182905260a0810182905260c081019190915291505b600289810b600090815260208d9052604090205463010000009004810b9087900b811315611540575085611565565b600281900b600090815260208d905260409020805462ffffff191662ffffff8b161790555b8860020b8a60020b12158061158057508060020b8960020b12155b1561159e5760405163044f7fb160e51b815260040160405180910390fd5b60405180606001604052808b60020b81526020018260020b8152602001600063ffffffff168152508c60008b60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550905050888c60008c60020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff160217905550505b600286810b600090815260208d9052604090205463010000008104820b910b146117255783156116e8576116c98186612262565b905084816000018181516116dd919061317b565b600f0b905250611974565b84816000018181516116fa919061310a565b600f0b905250602081018051869190611714908390613150565b6001600160801b0316905250611974565b831561176e57506040805160e081018252600f86900b8152600060208201819052918101829052606081018290526080810182905260a0810182905260c08101919091526117be565b6040518060e0016040528086611783906131c1565b600f0b81526001600160801b0387166020820152600060408201819052606082018190526080820181905260a0820181905260c09091015290505b600287810b600090815260208d90526040902054810b9089900b8112156117e25750875b600288810b600090815260208e9052604090205463010000008104820b910b148061181357508660020b8860020b13155b8061182457508060020b8760020b13155b15611842576040516329f7012160e21b815260040160405180910390fd5b60405180606001604052808260020b81526020018960020b8152602001600063ffffffff168152508c60008960020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff160217905550905050868c60008360020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff160217905550868c60008a60020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff160217905550505b818c60008a60020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b03160217905550905050808c60008860020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b0316021790555090505089925050509998505050505050505050565b600286810b600090815260208b8152604091829020825160e0810184528154600f81900b82526001600160801b03600160801b91829004811694830194909452600183015480851695830195909552938490048316606082015293015490811660808401526001600160401b03918104821660a0840152600160c01b90041660c08201528215611d85578315611d325780602001516001600160801b0316856001600160801b031603611cf557611cf281600061268f565b90505b8481600001818151611d07919061317b565b600f0b905250602081018051869190611d219083906130e2565b6001600160801b0316905250611de2565b60208101518151611d439190613150565b6001600160801b0316856001600160801b031603611d6857611d6681600161268f565b505b8481600001818151611d7a919061310a565b600f0b905250611de2565b8315611de2578560020b8760020b03611dc35780604001516001600160801b0316856001600160801b031603611dc357611dc081600061268f565b90505b8481604001818151611dd591906130e2565b6001600160801b03169052505b808a60008960020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b031602179055509050505060008960008760020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b031681525050905081156121625783156120fa57602081015181516120b89190613150565b6001600160801b0316856001600160801b0316036120dd576120db81600161268f565b505b84816000018181516120ef919061310a565b600f0b9052506121be565b80602001516001600160801b0316856001600160801b0316036121255761212281600061268f565b90505b8481600001818151612137919061317b565b600f0b9052506020810180518691906121519083906130e2565b6001600160801b03169052506121be565b836121be578560020b8760020b0361219f5780604001516001600160801b0316856001600160801b03160361219f5761219c81600061268f565b90505b84816040018181516121b191906130e2565b6001600160801b03169052505b600295860b600090815260209a8b5260409081902082519b8301516001600160801b039c8d16600160801b918e168202178255918301516060840151908d16908d16830217600182015560808301519701805460a084015160c09094015198909c166001600160c01b0319909c169b909b176001600160401b03928316909102176001600160c01b0316600160c01b91909616029490941790975550505050505050565b6040805160e081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c081019190915260a08301516001600160401b03161561268857602083015183516000916122c19161317b565b6001600160801b031690506000670de0b6b3a76400008560a001516001600160401b031686606001516001600160801b03166122fd9190612e7b565b6123079190612eb0565b9050808560600181815161231b91906130e2565b6001600160801b031690525060405163554d048960e11b81526004810182905260248101839052600160601b604482015260009073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a09129082908290606401602060405180830381865af415801561238f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906123b39190612edc565b600160601b6123cb6001600160801b038a1688612ec4565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526044820152606401602060405180830381865af4158015612414573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906124389190612edc565b6001600160801b03169050670de0b6b3a764000086606001516001600160801b0316826124659190612e7b565b61246f9190612eb0565b6001600160401b031660a0870152606086018051829190612491908390613150565b6001600160801b0316905250505060c08401516001600160401b031615612686576000670de0b6b3a76400008560c001516001600160401b031686608001516001600160801b03166124e39190612e7b565b6124ed9190612eb0565b9050808560800181815161250191906130e2565b6001600160801b031690525060405163554d048960e11b81526004810182905260248101839052600160601b604482015260009073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a09129082908290606401602060405180830381865af4158015612575573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906125999190612edc565b600160601b6125b16001600160801b038a1688612ec4565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526044820152606401602060405180830381865af41580156125fa573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061261e9190612edc565b6001600160801b03169050670de0b6b3a764000086608001516001600160801b03168261264b9190612e7b565b6126559190612eb0565b6001600160401b031660c0870152608086018051829190612677908390613150565b6001600160801b031690525050505b505b5090919050565b6040805160e081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c081019190915281156127b45760a08301516001600160401b0316156127af57670de0b6b3a76400008360a001516001600160401b031684606001516001600160801b03166127109190612e7b565b61271a9190612eb0565b8360600181815161272b91906130e2565b6001600160801b0316905250600060a084015260c08301516001600160401b0316156127af57670de0b6b3a76400008360c001516001600160401b031684608001516001600160801b03166127809190612e7b565b61278a9190612eb0565b8360800181815161279b91906130e2565b6001600160801b0316905250600060c08401525b612688565b60a08301516001600160401b03161561288957670de0b6b3a76400008360a001516001600160401b031684606001516001600160801b03166127f69190612e7b565b6128009190612eb0565b6001600160801b03166060840152670de0b6b3a764000060a084015260c08301516001600160401b0316156127af57670de0b6b3a76400008360c001516001600160401b031684608001516001600160801b031661285e9190612e7b565b6128689190612eb0565b6001600160801b03166080840152670de0b6b3a764000060c0840152612688565b5050600060608201819052608082015290565b604080516101a081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e08101829052610100810182905261012081018290526101408101829052610160810182905261018081019190915290565b8035801515811461291857600080fd5b919050565b6001600160a01b038116811461293257600080fd5b50565b80356129188161291d565b6040516101a081016001600160401b038111828210171561297157634e487b7160e01b600052604160045260246000fd5b60405290565b60405161010081016001600160401b038111828210171561297157634e487b7160e01b600052604160045260246000fd5b60ff8116811461293257600080fd5b8035612918816129a8565b803561ffff8116811461291857600080fd5b8035600181900b811461291857600080fd5b8060020b811461293257600080fd5b8035612918816129e6565b803563ffffffff8116811461291857600080fd5b80356001600160801b038116811461291857600080fd5b60006101a08284031215612a3e57600080fd5b612a46612940565b9050612a51826129b7565b8152612a5f602083016129c2565b6020820152612a70604083016129d4565b6040820152612a81606083016129c2565b6060820152612a92608083016129c2565b6080820152612aa360a083016129f5565b60a0820152612ab460c08301612a00565b60c0820152612ac560e08301612a00565b60e0820152610100612ad8818401612a00565b90820152610120612aea838201612a00565b90820152610140612afc838201612a14565b90820152610160612b0e838201612935565b90820152610180612b20838201612935565b9082015292915050565b6000806000808486036102e0811215612b4257600080fd5b612b4b86612908565b94506020860135612b5b8161291d565b9350612b6a8760408801612a2b565b92506101006101df1982011215612b8057600080fd5b50612b89612977565b6101e08601358152610200860135602082015261022086013560408201526102408601356060820152610260860135608082015261028086013560a08201526102a086013560c08201526102c09095013560e0860152509194909350909190565b6000806000806102008587031215612c0157600080fd5b843593506020850135925060408501359150612c208660608701612a2b565b905092959194509250565b815160ff1681526101a081016020830151612c4c602084018261ffff169052565b506040830151612c61604084018260010b9052565b506060830151612c77606084018261ffff169052565b506080830151612c8d608084018261ffff169052565b5060a0830151612ca260a084018260020b9052565b5060c0830151612cba60c084018263ffffffff169052565b5060e0830151612cd260e084018263ffffffff169052565b506101008381015163ffffffff908116918401919091526101208085015190911690830152610140808401516001600160801b031690830152610160808401516001600160a01b03908116918401919091526101809384015116929091019190915290565b60008060008060008060008060006102a08a8c031215612d5657600080fd5b8935985060208a01359750612d6e8b60408c01612a2b565b96506101e08a0135612d7f816129e6565b95506102008a0135612d90816129e6565b94506102208a0135612da1816129e6565b93506102408a0135612db2816129e6565b9250612dc16102608b01612a14565b9150612dd06102808b01612908565b90509295985092959850929598565b60008060008060008060008060006102a08a8c031215612dfe57600080fd5b8935985060208a01359750612e168b60408c01612a2b565b96506101e08a0135612e27816129e6565b95506102008a0135612e38816129e6565b9450612e476102208b01612a14565b9350612e566102408b01612908565b9250612dc16102608b01612908565b634e487b7160e01b600052601160045260246000fd5b6000816000190483118215151615612e9557612e95612e65565b500290565b634e487b7160e01b600052601260045260246000fd5b600082612ebf57612ebf612e9a565b500490565b60008219821115612ed757612ed7612e65565b500190565b600060208284031215612eee57600080fd5b5051919050565b600082821015612f0757612f07612e65565b500390565b60008060408385031215612f1f57600080fd5b8251612f2a816129a8565b6020840151909250612f3b816129e6565b809150509250929050565b60008160020b8360020b80612f5d57612f5d612e9a565b627fffff19821460001982141615612f7757612f77612e65565b90059392505050565b60008160020b8360020b627fffff600082136000841383830485118282161615612fac57612fac612e65565b627fffff196000851282811687830587121615612fcb57612fcb612e65565b60008712925085820587128484161615612fe757612fe7612e65565b85850587128184161615612ffd57612ffd612e65565b5050509290910295945050505050565b60006020828403121561301f57600080fd5b815161302a8161291d565b9392505050565b60008160020b627fffff19810361304a5761304a612e65565b60000392915050565b60008160020b8360020b6000811281627fffff190183128115161561307a5761307a612e65565b81627fffff01831381161561309157613091612e65565b5090039392505050565b60008160020b8360020b6000821282627fffff038213811516156130c1576130c1612e65565b82627fffff190382128116156130d9576130d9612e65565b50019392505050565b60006001600160801b038381169083168181101561310257613102612e65565b039392505050565b600081600f0b83600f0b600081128160016001607f1b03190183128115161561313557613135612e65565b8160016001607f1b0301831381161561309157613091612e65565b60006001600160801b0380831681851680830382111561317257613172612e65565b01949350505050565b600081600f0b83600f0b600082128260016001607f1b03038213811516156131a5576131a5612e65565b8260016001607f1b03190382128116156130d9576130d9612e65565b600081600f0b60016001607f1b0319810361304a5761304a612e6556fea264697066735822122067c92043a999a460ecb53bc4f2200e0c5fa50690527f0ca6d29d19c0524c5d2e64736f6c634300080d0033";

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
