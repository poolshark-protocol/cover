/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type { SwapLib, SwapLibInterface } from "../SwapLib";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "output",
        type: "uint256",
      },
      {
        internalType: "uint24",
        name: "swapFee",
        type: "uint24",
      },
      {
        internalType: "uint256",
        name: "currentLiquidity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalFeeAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amountOut",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "protocolFee",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "feeGrowthGlobal",
        type: "uint256",
      },
    ],
    name: "handleFees",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
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
];

export class SwapLib__factory {
  static readonly abi = _abi;
  static createInterface(): SwapLibInterface {
    return new utils.Interface(_abi) as SwapLibInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): SwapLib {
    return new Contract(address, _abi, signerOrProvider) as SwapLib;
  }
}
