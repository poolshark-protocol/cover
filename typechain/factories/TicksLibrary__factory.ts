/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type { TicksLibrary, TicksLibraryInterface } from "../TicksLibrary";

const _abi = [
  {
    inputs: [],
    name: "NotImplementedYet",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickClaimedAt",
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
];

export class TicksLibrary__factory {
  static readonly abi = _abi;
  static createInterface(): TicksLibraryInterface {
    return new utils.Interface(_abi) as TicksLibraryInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TicksLibrary {
    return new Contract(address, _abi, signerOrProvider) as TicksLibrary;
  }
}
