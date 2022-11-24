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
  CallOverrides,
} from "ethers";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";
import type { TypedEventFilter, TypedEvent, TypedListener } from "./common";

interface ITickMathInterface extends ethers.utils.Interface {
  functions: {
    "MAX_SQRT_RATIO()": FunctionFragment;
    "MAX_TICK()": FunctionFragment;
    "MIN_SQRT_RATIO()": FunctionFragment;
    "MIN_TICK()": FunctionFragment;
    "getSqrtRatioAtTick(int24)": FunctionFragment;
    "getTickAtSqrtRatio(uint160)": FunctionFragment;
    "validatePrice(uint160)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "MAX_SQRT_RATIO",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "MAX_TICK", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "MIN_SQRT_RATIO",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "MIN_TICK", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "getSqrtRatioAtTick",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getTickAtSqrtRatio",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "validatePrice",
    values: [BigNumberish]
  ): string;

  decodeFunctionResult(
    functionFragment: "MAX_SQRT_RATIO",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "MAX_TICK", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "MIN_SQRT_RATIO",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "MIN_TICK", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getSqrtRatioAtTick",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getTickAtSqrtRatio",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "validatePrice",
    data: BytesLike
  ): Result;

  events: {};
}

export class ITickMath extends BaseContract {
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

  interface: ITickMathInterface;

  functions: {
    MAX_SQRT_RATIO(
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { ratio: BigNumber }>;

    MAX_TICK(overrides?: CallOverrides): Promise<[number] & { tick: number }>;

    MIN_SQRT_RATIO(
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { ratio: BigNumber }>;

    MIN_TICK(overrides?: CallOverrides): Promise<[number] & { tick: number }>;

    getSqrtRatioAtTick(
      tick: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { sqrtPriceX96: BigNumber }>;

    getTickAtSqrtRatio(
      sqrtPriceX96: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[number] & { tick: number }>;

    validatePrice(
      price: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[void]>;
  };

  MAX_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

  MAX_TICK(overrides?: CallOverrides): Promise<number>;

  MIN_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

  MIN_TICK(overrides?: CallOverrides): Promise<number>;

  getSqrtRatioAtTick(
    tick: BigNumberish,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  getTickAtSqrtRatio(
    sqrtPriceX96: BigNumberish,
    overrides?: CallOverrides
  ): Promise<number>;

  validatePrice(price: BigNumberish, overrides?: CallOverrides): Promise<void>;

  callStatic: {
    MAX_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

    MAX_TICK(overrides?: CallOverrides): Promise<number>;

    MIN_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

    MIN_TICK(overrides?: CallOverrides): Promise<number>;

    getSqrtRatioAtTick(
      tick: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getTickAtSqrtRatio(
      sqrtPriceX96: BigNumberish,
      overrides?: CallOverrides
    ): Promise<number>;

    validatePrice(
      price: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {};

  estimateGas: {
    MAX_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

    MAX_TICK(overrides?: CallOverrides): Promise<BigNumber>;

    MIN_SQRT_RATIO(overrides?: CallOverrides): Promise<BigNumber>;

    MIN_TICK(overrides?: CallOverrides): Promise<BigNumber>;

    getSqrtRatioAtTick(
      tick: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getTickAtSqrtRatio(
      sqrtPriceX96: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    validatePrice(
      price: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    MAX_SQRT_RATIO(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    MAX_TICK(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    MIN_SQRT_RATIO(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    MIN_TICK(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    getSqrtRatioAtTick(
      tick: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getTickAtSqrtRatio(
      sqrtPriceX96: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    validatePrice(
      price: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
