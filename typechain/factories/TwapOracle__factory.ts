/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type { TwapOracle, TwapOracleInterface } from "../TwapOracle";

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
];

export class TwapOracle__factory {
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
