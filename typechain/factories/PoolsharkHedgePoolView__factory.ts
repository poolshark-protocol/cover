/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers";
import { Provider } from "@ethersproject/providers";
import type {
  PoolsharkHedgePoolView,
  PoolsharkHedgePoolViewInterface,
} from "../PoolsharkHedgePoolView";

const _abi = [
  {
    inputs: [],
    name: "InvalidPosition",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidSwapFee",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidTick",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidTickSpread",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidToken",
    type: "error",
  },
  {
    inputs: [],
    name: "LiquidityOverflow",
    type: "error",
  },
  {
    inputs: [],
    name: "Locked",
    type: "error",
  },
  {
    inputs: [],
    name: "LowerNotEvenTick",
    type: "error",
  },
  {
    inputs: [],
    name: "MaxTickLiquidity",
    type: "error",
  },
  {
    inputs: [],
    name: "NotEnoughOutputLiquidity",
    type: "error",
  },
  {
    inputs: [],
    name: "Overflow",
    type: "error",
  },
  {
    inputs: [],
    name: "Token0Missing",
    type: "error",
  },
  {
    inputs: [],
    name: "Token1Missing",
    type: "error",
  },
  {
    inputs: [],
    name: "UpperNotOddTick",
    type: "error",
  },
  {
    inputs: [],
    name: "WaitUntilEnoughObservations",
    type: "error",
  },
  {
    inputs: [],
    name: "feeTo",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "globalState",
    outputs: [
      {
        internalType: "uint24",
        name: "swapFee",
        type: "uint24",
      },
      {
        internalType: "int24",
        name: "tickSpread",
        type: "int24",
      },
      {
        internalType: "uint32",
        name: "lastBlockNumber",
        type: "uint32",
      },
      {
        internalType: "uint8",
        name: "unlocked",
        type: "uint8",
      },
      {
        internalType: "int24",
        name: "latestTick",
        type: "int24",
      },
      {
        internalType: "uint32",
        name: "accumEpoch",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pool0",
    outputs: [
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        internalType: "uint128",
        name: "feeGrowthCurrentEpoch",
        type: "uint128",
      },
      {
        internalType: "uint160",
        name: "price",
        type: "uint160",
      },
      {
        internalType: "int24",
        name: "nearestTick",
        type: "int24",
      },
      {
        internalType: "int24",
        name: "lastTick",
        type: "int24",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pool1",
    outputs: [
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        internalType: "uint128",
        name: "feeGrowthCurrentEpoch",
        type: "uint128",
      },
      {
        internalType: "uint160",
        name: "price",
        type: "uint160",
      },
      {
        internalType: "int24",
        name: "nearestTick",
        type: "int24",
      },
      {
        internalType: "int24",
        name: "lastTick",
        type: "int24",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "positions0",
    outputs: [
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        internalType: "uint32",
        name: "accumEpochLast",
        type: "uint32",
      },
      {
        internalType: "uint160",
        name: "claimPriceLast",
        type: "uint160",
      },
      {
        internalType: "uint128",
        name: "amountIn",
        type: "uint128",
      },
      {
        internalType: "uint128",
        name: "amountOut",
        type: "uint128",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "positions1",
    outputs: [
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        internalType: "uint32",
        name: "accumEpochLast",
        type: "uint32",
      },
      {
        internalType: "uint160",
        name: "claimPriceLast",
        type: "uint160",
      },
      {
        internalType: "uint128",
        name: "amountIn",
        type: "uint128",
      },
      {
        internalType: "uint128",
        name: "amountOut",
        type: "uint128",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "tickNodes",
    outputs: [
      {
        internalType: "int24",
        name: "previousTick",
        type: "int24",
      },
      {
        internalType: "int24",
        name: "nextTick",
        type: "int24",
      },
      {
        internalType: "uint32",
        name: "accumEpochLast",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "ticks0",
    outputs: [
      {
        internalType: "int104",
        name: "liquidityDelta",
        type: "int104",
      },
      {
        internalType: "uint104",
        name: "liquidityDeltaMinus",
        type: "uint104",
      },
      {
        internalType: "int88",
        name: "amountInDelta",
        type: "int88",
      },
      {
        internalType: "int88",
        name: "amountOutDelta",
        type: "int88",
      },
      {
        internalType: "uint64",
        name: "amountInDeltaCarryPercent",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "amountOutDeltaCarryPercent",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "ticks1",
    outputs: [
      {
        internalType: "int104",
        name: "liquidityDelta",
        type: "int104",
      },
      {
        internalType: "uint104",
        name: "liquidityDeltaMinus",
        type: "uint104",
      },
      {
        internalType: "int88",
        name: "amountInDelta",
        type: "int88",
      },
      {
        internalType: "int88",
        name: "amountOutDelta",
        type: "int88",
      },
      {
        internalType: "uint64",
        name: "amountInDeltaCarryPercent",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "amountOutDeltaCarryPercent",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "utils",
    outputs: [
      {
        internalType: "contract IPoolsharkUtils",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

export class PoolsharkHedgePoolView__factory {
  static readonly abi = _abi;
  static createInterface(): PoolsharkHedgePoolViewInterface {
    return new utils.Interface(_abi) as PoolsharkHedgePoolViewInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): PoolsharkHedgePoolView {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as PoolsharkHedgePoolView;
  }
}
