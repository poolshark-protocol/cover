/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import {
  ethers,
  EventFilter,
  Signer,
  BigNumber,
  BigNumberish,
  PopulatedTransaction,
  BaseContract,
  ContractTransaction,
} from "ethers";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";
import type { TypedEventFilter, TypedEvent, TypedListener } from "./common";

interface CoverPoolEventsInterface extends ethers.utils.Interface {
  functions: {};

  events: {
    "Burn(address,int24,int24,int24,bool,uint128)": EventFragment;
    "Collect(address,uint256,uint256)": EventFragment;
    "Mint(address,int24,int24,bool,uint128)": EventFragment;
    "PoolCreated(address,address,address,uint24,int24)": EventFragment;
    "Swap(address,address,address,uint256,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "Burn"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Collect"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Mint"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "PoolCreated"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Swap"): EventFragment;
}

export type BurnEvent = TypedEvent<
  [string, number, number, number, boolean, BigNumber] & {
    owner: string;
    lower: number;
    upper: number;
    claim: number;
    zeroForOne: boolean;
    liquidityBurned: BigNumber;
  }
>;

export type CollectEvent = TypedEvent<
  [string, BigNumber, BigNumber] & {
    sender: string;
    amount0: BigNumber;
    amount1: BigNumber;
  }
>;

export type MintEvent = TypedEvent<
  [string, number, number, boolean, BigNumber] & {
    owner: string;
    lower: number;
    upper: number;
    zeroForOne: boolean;
    liquidityMinted: BigNumber;
  }
>;

export type PoolCreatedEvent = TypedEvent<
  [string, string, string, number, number] & {
    pool: string;
    token0: string;
    token1: string;
    fee: number;
    tickSpacing: number;
  }
>;

export type SwapEvent = TypedEvent<
  [string, string, string, BigNumber, BigNumber] & {
    recipient: string;
    tokenIn: string;
    tokenOut: string;
    amountIn: BigNumber;
    amountOut: BigNumber;
  }
>;

export class CoverPoolEvents extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  listeners<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter?: TypedEventFilter<EventArgsArray, EventArgsObject>
  ): Array<TypedListener<EventArgsArray, EventArgsObject>>;
  off<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  on<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  once<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  removeListener<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  removeAllListeners<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>
  ): this;

  listeners(eventName?: string): Array<Listener>;
  off(eventName: string, listener: Listener): this;
  on(eventName: string, listener: Listener): this;
  once(eventName: string, listener: Listener): this;
  removeListener(eventName: string, listener: Listener): this;
  removeAllListeners(eventName?: string): this;

  queryFilter<EventArgsArray extends Array<any>, EventArgsObject>(
    event: TypedEventFilter<EventArgsArray, EventArgsObject>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEvent<EventArgsArray & EventArgsObject>>>;

  interface: CoverPoolEventsInterface;

  functions: {};

  callStatic: {};

  filters: {
    "Burn(address,int24,int24,int24,bool,uint128)"(
      owner?: string | null,
      lower?: BigNumberish | null,
      upper?: BigNumberish | null,
      claim?: null,
      zeroForOne?: null,
      liquidityBurned?: null
    ): TypedEventFilter<
      [string, number, number, number, boolean, BigNumber],
      {
        owner: string;
        lower: number;
        upper: number;
        claim: number;
        zeroForOne: boolean;
        liquidityBurned: BigNumber;
      }
    >;

    Burn(
      owner?: string | null,
      lower?: BigNumberish | null,
      upper?: BigNumberish | null,
      claim?: null,
      zeroForOne?: null,
      liquidityBurned?: null
    ): TypedEventFilter<
      [string, number, number, number, boolean, BigNumber],
      {
        owner: string;
        lower: number;
        upper: number;
        claim: number;
        zeroForOne: boolean;
        liquidityBurned: BigNumber;
      }
    >;

    "Collect(address,uint256,uint256)"(
      sender?: string | null,
      amount0?: null,
      amount1?: null
    ): TypedEventFilter<
      [string, BigNumber, BigNumber],
      { sender: string; amount0: BigNumber; amount1: BigNumber }
    >;

    Collect(
      sender?: string | null,
      amount0?: null,
      amount1?: null
    ): TypedEventFilter<
      [string, BigNumber, BigNumber],
      { sender: string; amount0: BigNumber; amount1: BigNumber }
    >;

    "Mint(address,int24,int24,bool,uint128)"(
      owner?: string | null,
      lower?: BigNumberish | null,
      upper?: BigNumberish | null,
      zeroForOne?: null,
      liquidityMinted?: null
    ): TypedEventFilter<
      [string, number, number, boolean, BigNumber],
      {
        owner: string;
        lower: number;
        upper: number;
        zeroForOne: boolean;
        liquidityMinted: BigNumber;
      }
    >;

    Mint(
      owner?: string | null,
      lower?: BigNumberish | null,
      upper?: BigNumberish | null,
      zeroForOne?: null,
      liquidityMinted?: null
    ): TypedEventFilter<
      [string, number, number, boolean, BigNumber],
      {
        owner: string;
        lower: number;
        upper: number;
        zeroForOne: boolean;
        liquidityMinted: BigNumber;
      }
    >;

    "PoolCreated(address,address,address,uint24,int24)"(
      pool?: null,
      token0?: null,
      token1?: null,
      fee?: null,
      tickSpacing?: null
    ): TypedEventFilter<
      [string, string, string, number, number],
      {
        pool: string;
        token0: string;
        token1: string;
        fee: number;
        tickSpacing: number;
      }
    >;

    PoolCreated(
      pool?: null,
      token0?: null,
      token1?: null,
      fee?: null,
      tickSpacing?: null
    ): TypedEventFilter<
      [string, string, string, number, number],
      {
        pool: string;
        token0: string;
        token1: string;
        fee: number;
        tickSpacing: number;
      }
    >;

    "Swap(address,address,address,uint256,uint256)"(
      recipient?: string | null,
      tokenIn?: string | null,
      tokenOut?: string | null,
      amountIn?: null,
      amountOut?: null
    ): TypedEventFilter<
      [string, string, string, BigNumber, BigNumber],
      {
        recipient: string;
        tokenIn: string;
        tokenOut: string;
        amountIn: BigNumber;
        amountOut: BigNumber;
      }
    >;

    Swap(
      recipient?: string | null,
      tokenIn?: string | null,
      tokenOut?: string | null,
      amountIn?: null,
      amountOut?: null
    ): TypedEventFilter<
      [string, string, string, BigNumber, BigNumber],
      {
        recipient: string;
        tokenIn: string;
        tokenOut: string;
        amountIn: BigNumber;
        amountOut: BigNumber;
      }
    >;
  };

  estimateGas: {};

  populateTransaction: {};
}
