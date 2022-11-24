/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Ticks, TicksInterface } from "../Ticks";

const _abi = [
  {
    inputs: [],
    name: "NotImplementedYet",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickLowerOrder",
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
    name: "WrongTickUpperOrder",
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
        internalType: "uint24",
        name: "_tickSpacing",
        type: "uint24",
      },
    ],
    name: "getMaxLiquidity",
    outputs: [
      {
        internalType: "uint128",
        name: "",
        type: "uint128",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x61122d61003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100565760003560e01c8063121f0e0c1461005b5780636345a01714610093578063aa62b776146100b3578063dc47a5c2146100f2575b600080fd5b81801561006757600080fd5b5061007b610076366004610eda565b61011d565b60405160029190910b81526020015b60405180910390f35b81801561009f57600080fd5b5061007b6100ae366004610f50565b61038e565b8180156100bf57600080fd5b506100d36100ce366004611025565b610d55565b60408051938452600292830b6020850152910b9082015260600161008a565b6101056101003660046110b0565b610e6c565b6040516001600160801b03909116815260200161008a565b600284900b60008181526020879052604081209091620d89e7191480159061015b575060028101546001600160801b03858116600160801b90920416145b15610225578054600281810b600090815260208a9052604080822063010000009485900480850b845291909220825465ffffff000000191662ffffff9283169095029490941782558454845462ffffff19169116178355919088810b9086900b036101c857825460020b94505b5050600286810b600090815260208990526040812080546001600160b01b03191681556001810182905591820181905560038201556004810180546001600160801b031916905560050180546001600160a01b0319169055610249565b6002810180546001600160801b03600160801b808304821688900382160291161790555b50600284900b600090815260208790526040902061026a620d89e7196110e8565b60020b8560020b14158015610295575060028101546001600160801b03858116600160801b90920416145b1561035f578054600281810b600090815260208a9052604080822063010000009485900480850b845291909220825465ffffff000000191662ffffff9283169095029490941782558454845462ffffff19169116178355919087810b9086900b0361030257825460020b94505b5050600285810b600090815260208990526040812080546001600160b01b03191681556001810182905591820181905560038201556004810180546001600160801b031916905560050180546001600160a01b0319169055610383565b6002810180546001600160801b03600160801b808304821688900382160291161790555b509095945050505050565b60008560020b8860020b1215806103ab57508660020b8960020b12155b156103c95760405163338d790760e01b815260040160405180910390fd5b600288900b620d89e71913156103f2576040516345bde0e360e11b815260040160405180910390fd5b6103ff620d89e7196110e8565b60020b8660020b13156104255760405163093cbe4760e21b815260040160405180910390fd5b60405163986cfba360e01b8152600289900b60048201526001600160a01b0384169073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610483573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104a7919061110a565b6001600160a01b0316111561088257600288810b600090815260208e9052604090200154600160801b90046001600160801b0316801515806104f05750600289900b620d89e719145b15610543576104ff8682611127565b8d60008b60020b60020b815260200190815260200160002060020160106101000a8154816001600160801b0302191690836001600160801b03160217905550610880565b60028a810b600090815260208f905260409020805490916301000000909104810b9089900b8113156105725750875b6002820154600160801b90046001600160801b031615801561059c575060028c900b620d89e71914155b806105ad57508a60020b8c60020b12155b806105be57508060020b8b60020b12155b156105dc576040516307dfb2f760e01b815260040160405180910390fd5b6040518061014001604052808d60020b81526020018260020b815260200160006001600160801b0316815260200160006001600160801b0316815260200160006001600160801b0316815260200160006001600160801b03168152602001896001600160801b031681526020018f815260200160006001600160801b031681526020018e6001600160a01b03168152508f60008d60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060c08201518160020160106101000a8154816001600160801b0302191690836001600160801b0316021790555060e082015181600301556101008201518160040160006101000a8154816001600160801b0302191690836001600160801b031602179055506101208201518160050160006101000a8154816001600160a01b0302191690836001600160a01b031602179055509050508a8260000160036101000a81548162ffffff021916908360020b62ffffff1602179055508a8f60008360020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff16021790555050505b505b60405163986cfba360e01b8152600287900b60048201526001600160a01b0384169073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156108e0573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610904919061110a565b6001600160a01b03161115610cf957600286810b600090815260208e9052604090200154600160801b90046001600160801b031680151580610957575061094e620d89e7196110e8565b60020b8760020b145b156109aa576109668682611127565b8d60008960020b60020b815260200190815260200160002060020160106101000a8154816001600160801b0302191690836001600160801b03160217905550610cf7565b600288810b600090815260208f90526040902080548183015491926301000000909104900b90600160801b90046001600160801b03161580156109ff57506109f5620d89e7196110e8565b60020b8a60020b14155b80610a1057508860020b8a60020b13155b80610a2157508060020b8960020b12155b15610a3f576040516315beab4760e01b815260040160405180910390fd5b815460028c810b91900b1215610a53578a99505b6040518061014001604052808b60020b81526020018260020b815260200160006001600160801b0316815260200160006001600160801b0316815260200160006001600160801b0316815260200160006001600160801b03168152602001896001600160801b031681526020018f815260200160006001600160801b031681526020018e6001600160a01b03168152508f60008b60020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060c08201518160020160106101000a8154816001600160801b0302191690836001600160801b0316021790555060e082015181600301556101008201518160040160006101000a8154816001600160801b0302191690836001600160801b031602179055506101208201518160050160006101000a8154816001600160a01b0302191690836001600160a01b03160217905550905050888260000160036101000a81548162ffffff021916908360020b62ffffff160217905550888f60008360020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff16021790555050505b505b8560020b8460020b128015610d1457508160020b8660020b13155b15610d2157859350610d45565b8760020b8460020b128015610d3c57508160020b8860020b13155b15610d45578793505b50919a9950505050505050505050565b600286900b60009081526020899052604081206005015481908190610d83906001600160a01b031689611152565b60028a900b600090815260208d90526040902060050180546001600160a01b0319166001600160a01b03929092169190911790558415610e425760028460020b8a60020b81610dd457610dd461117a565b0560020b81610de557610de561117a565b0760020b600003610e1a57600289810b600090815260208d9052604090200154600160801b90046001600160801b0316909603955b600289810b600090815260208d9052604090206003810188905554999a509890980b97610e5b565b604051633e231d6d60e21b815260040160405180910390fd5b509499979850959695505050505050565b6000610e79826002611190565b610e86620d89e7196110e8565b610e9091906111bb565b610ea69062ffffff166001600160801b036111dd565b92915050565b8035600281900b8114610ebe57600080fd5b919050565b80356001600160801b0381168114610ebe57600080fd5b600080600080600060a08688031215610ef257600080fd5b85359450610f0260208701610eac565b9350610f1060408701610eac565b9250610f1e60608701610ec3565b9150610f2c60808701610eac565b90509295509295909350565b6001600160a01b0381168114610f4d57600080fd5b50565b60008060008060008060008060008060006101608c8e031215610f7257600080fd5b8b359a5060208c0135995060408c0135610f8b81610f38565b9850610f9960608d01610eac565b9750610fa760808d01610eac565b9650610fb560a08d01610eac565b9550610fc360c08d01610eac565b9450610fd160e08d01610ec3565b9350610fe06101008d01610eac565b92506101208c0135610ff181610f38565b91506110006101408d01610eac565b90509295989b509295989b9093969950565b803562ffffff81168114610ebe57600080fd5b600080600080600080600080610100898b03121561104257600080fd5b8835975061105260208a01610eac565b965061106060408a01610eac565b9550606089013561107081610f38565b94506080890135935060a0890135925060c0890135801515811461109357600080fd5b91506110a160e08a01611012565b90509295985092959890939650565b6000602082840312156110c257600080fd5b6110cb82611012565b9392505050565b634e487b7160e01b600052601160045260246000fd5b60008160020b627fffff198103611101576111016110d2565b60000392915050565b60006020828403121561111c57600080fd5b81516110cb81610f38565b60006001600160801b03808316818516808303821115611149576111496110d2565b01949350505050565b60006001600160a01b0383811690831681811015611172576111726110d2565b039392505050565b634e487b7160e01b600052601260045260246000fd5b600062ffffff808316818516818304811182151516156111b2576111b26110d2565b02949350505050565b600062ffffff808416806111d1576111d161117a565b92169190910492915050565b60006001600160801b03808416806111d1576111d161117a56fea26469706673582212203ea52b21e94e7a385e646c6eee31cbdd3ac4f2a9f070dbdfd50ff052c3828ddd64736f6c634300080d0033";

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
  ["contracts/libraries/TickMath.sol:TickMath"]: string;
}
