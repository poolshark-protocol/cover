/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { TwapOracle, TwapOracleInterface } from "../TwapOracle";

const _abi = [
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
];

const _bytecode =
  "0x6080604052348015600f57600080fd5b5060918061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c8063786570c214602d575b600080fd5b600054603f906001600160a01b031681565b6040516001600160a01b03909116815260200160405180910390f3fea2646970667358221220bba35547aea019ff1d1ec2c5647107eb1526431e0d655375edda892c5ea9854e64736f6c634300080d0033";

export class TwapOracle__factory extends ContractFactory {
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
  ): Promise<TwapOracle> {
    return super.deploy(overrides || {}) as Promise<TwapOracle>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): TwapOracle {
    return super.attach(address) as TwapOracle;
  }
  connect(signer: Signer): TwapOracle__factory {
    return super.connect(signer) as TwapOracle__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TwapOracleInterface {
    return new utils.Interface(_abi) as TwapOracleInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TwapOracle {
    return new Contract(address, _abi, signerOrProvider) as TwapOracle;
  }
}
