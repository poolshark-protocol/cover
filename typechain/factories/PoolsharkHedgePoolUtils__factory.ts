/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  PoolsharkHedgePoolUtils,
  PoolsharkHedgePoolUtilsInterface,
} from "../PoolsharkHedgePoolUtils";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract IConcentratedPool",
        name: "pool",
        type: "address",
      },
    ],
    name: "calculateAverageTick",
    outputs: [
      {
        internalType: "int24",
        name: "averageTick",
        type: "int24",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "concentratedFactory",
    outputs: [
      {
        internalType: "contract IConcentratedFactory",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bool",
        name: "zeroForOne",
        type: "bool",
      },
    ],
    name: "getSqrtPriceLimitX96",
    outputs: [
      {
        internalType: "uint160",
        name: "",
        type: "uint160",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract IConcentratedPool",
        name: "pool",
        type: "address",
      },
    ],
    name: "initializePoolObservations",
    outputs: [
      {
        internalType: "int24",
        name: "startingTick",
        type: "int24",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract IConcentratedPool",
        name: "pool",
        type: "address",
      },
    ],
    name: "isPoolObservationsEnough",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "a",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "b",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "denominator",
        type: "uint256",
      },
    ],
    name: "mulDiv",
    outputs: [
      {
        internalType: "uint256",
        name: "result",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "a",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "b",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "denominator",
        type: "uint256",
      },
    ],
    name: "mulDivRoundingUp",
    outputs: [
      {
        internalType: "uint256",
        name: "result",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "x",
        type: "uint256",
      },
    ],
    name: "sqrt",
    outputs: [
      {
        internalType: "uint256",
        name: "z",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "a",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "b",
        type: "uint256",
      },
    ],
    name: "within1",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50610b54806100206000396000f3fe608060405234801561001057600080fd5b50600436106100935760003560e01c8063392b952d11610066578063392b952d1461013257806365e8e4d114610145578063677342ce14610158578063786570c21461016b578063aa9a09121461017e57600080fd5b80630af8b27f1461009857806313a1ec75146100be57806335393974146100e1578063382d7a8214610107575b600080fd5b6100ab6100a6366004610656565b610191565b6040519081526020015b60405180910390f35b6100d16100cc366004610682565b6101a8565b60405190151581526020016100b5565b6100f46100ef3660046106bc565b6101bd565b60405160029190910b81526020016100b5565b61011a6101153660046106e7565b6101e9565b6040516001600160a01b0390911681526020016100b5565b6100d16101403660046106bc565b610224565b6100f46101533660046106bc565b61022f565b6100ab610166366004610704565b61023a565b60005461011a906001600160a01b031681565b6100ab61018c366004610656565b610245565b600061019e848484610252565b90505b9392505050565b60006101b4838361028f565b90505b92915050565b60006101c8826102b1565b6101e0576101d58261032d565b50620d89e819919050565b6101b78261038a565b6000816102145761020f600173fffd8963efd1fc6a506488495d951d5263988d26610733565b6101b7565b6101b7640100000000600161075b565b60006101b7826102b1565b60006101b78261038a565b60006101b7826104f9565b600061019e8484846105a4565b600061025f8484846105a4565b9050818061026f5761026f610786565b838509156101a157600019811061028557600080fd5b6001019392505050565b6000818311156102a65750600181830311156101b7565b506001919003111590565b600080826001600160a01b0316633850c7bd6040518163ffffffff1660e01b815260040160e060405180830381865afa1580156102f2573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061031691906107ae565b5050600561ffff9091161015979650505050505050565b6040516332148f6760e01b8152600560048201526001600160a01b038216906332148f6790602401600060405180830381600087803b15801561036f57600080fd5b505af1158015610383573d6000803e3d6000fd5b5050505050565b60408051600380825260808201909252600091829190602082016060803683370190505090506000816000815181106103c5576103c5610863565b63ffffffff909216602092830291909101909101526103e66005600c610879565b61ffff16816001815181106103fd576103fd610863565b63ffffffff9092166020928302919091019091015260405163883bdbfd60e01b81526000906001600160a01b0385169063883bdbfd906104419085906004016108a3565b600060405180830381865afa15801561045e573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f1916820160405261048691908101906109b6565b5090508160018151811061049c5761049c610863565b602002602001015160030b816001815181106104ba576104ba610863565b6020026020010151826000815181106104d5576104d5610863565b60200260200101516104e79190610a82565b6104f19190610ad2565b949350505050565b60b581600160881b81106105125760409190911b9060801c5b6901000000000000000000811061052e5760209190911b9060401c5b6501000000000081106105465760109190911b9060201c5b6301000000811061055c5760089190911b9060101c5b62010000010260121c80820401600190811c80830401811c80830401811c80830401811c80830401811c80830401811c80830401901c80820481111561059f5781045b919050565b60008080600019858709858702925082811083820303915050806000036105dd57600084116105d257600080fd5b5082900490506101a1565b8084116105e957600080fd5b6000848688096000868103871696879004966002600389028118808a02820302808a02820302808a02820302808a02820302808a02820302808a02909103029181900381900460010186841190950394909402919094039290920491909117919091029150509392505050565b60008060006060848603121561066b57600080fd5b505081359360208301359350604090920135919050565b6000806040838503121561069557600080fd5b50508035926020909101359150565b6001600160a01b03811681146106b957600080fd5b50565b6000602082840312156106ce57600080fd5b81356101a1816106a4565b80151581146106b957600080fd5b6000602082840312156106f957600080fd5b81356101a1816106d9565b60006020828403121561071657600080fd5b5035919050565b634e487b7160e01b600052601160045260246000fd5b60006001600160a01b03838116908316818110156107535761075361071d565b039392505050565b60006001600160a01b0382811684821680830382111561077d5761077d61071d565b01949350505050565b634e487b7160e01b600052601260045260246000fd5b805161ffff8116811461059f57600080fd5b600080600080600080600060e0888a0312156107c957600080fd5b87516107d4816106a4565b8097505060208801518060020b81146107ec57600080fd5b95506107fa6040890161079c565b94506108086060890161079c565b93506108166080890161079c565b925060a088015160ff8116811461082c57600080fd5b60c089015190925061083d816106d9565b8091505092959891949750929550565b634e487b7160e01b600052604160045260246000fd5b634e487b7160e01b600052603260045260246000fd5b600061ffff8083168185168183048111821515161561089a5761089a61071d565b02949350505050565b6020808252825182820181905260009190848201906040850190845b818110156108e157835163ffffffff16835292840192918401916001016108bf565b50909695505050505050565b604051601f8201601f1916810167ffffffffffffffff811182821017156109165761091661084d565b604052919050565b600067ffffffffffffffff8211156109385761093861084d565b5060051b60200190565b600082601f83011261095357600080fd5b815160206109686109638361091e565b6108ed565b82815260059290921b8401810191818101908684111561098757600080fd5b8286015b848110156109ab57805161099e816106a4565b835291830191830161098b565b509695505050505050565b600080604083850312156109c957600080fd5b825167ffffffffffffffff808211156109e157600080fd5b818501915085601f8301126109f557600080fd5b81516020610a056109638361091e565b82815260059290921b84018101918181019089841115610a2457600080fd5b948201945b83861015610a525785518060060b8114610a435760008081fd5b82529482019490820190610a29565b91880151919650909350505080821115610a6b57600080fd5b50610a7885828601610942565b9150509250929050565b60008160060b8360060b6000811281667fffffffffffff1901831281151615610aad57610aad61071d565b81667fffffffffffff018313811615610ac857610ac861071d565b5090039392505050565b60008160060b8360060b80610af757634e487b7160e01b600052601260045260246000fd5b667fffffffffffff19821460001982141615610b1557610b1561071d565b9005939250505056fea2646970667358221220134200af5c71a045fb4ccaf6be7f20429fea0d77f1c7832f395fc5576345119464736f6c634300080d0033";

export class PoolsharkHedgePoolUtils__factory extends ContractFactory {
  constructor(
    ...args: [signer: Signer] | ConstructorParameters<typeof ContractFactory>
  ) {
    if (args.length === 1) {
      super(_abi, _bytecode, args[0]);
    } else {
      super(...args);
    }
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<PoolsharkHedgePoolUtils> {
    return super.deploy(overrides || {}) as Promise<PoolsharkHedgePoolUtils>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): PoolsharkHedgePoolUtils {
    return super.attach(address) as PoolsharkHedgePoolUtils;
  }
  connect(signer: Signer): PoolsharkHedgePoolUtils__factory {
    return super.connect(signer) as PoolsharkHedgePoolUtils__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): PoolsharkHedgePoolUtilsInterface {
    return new utils.Interface(_abi) as PoolsharkHedgePoolUtilsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): PoolsharkHedgePoolUtils {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as PoolsharkHedgePoolUtils;
  }
}
