/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { ethers } from "ethers";
import {
  FactoryOptions,
  HardhatEthersHelpers as HardhatEthersHelpersBase,
} from "@nomiclabs/hardhat-ethers/types";

import * as Contracts from ".";

declare module "hardhat/types/runtime" {
  interface HardhatEthersHelpers extends HardhatEthersHelpersBase {
    getContractFactory(
      name: "ERC20",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC20__factory>;
    getContractFactory(
      name: "ERC20Burnable",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ERC20Burnable__factory>;
    getContractFactory(
      name: "IERC20Metadata",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20Metadata__factory>;
    getContractFactory(
      name: "IERC20",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20__factory>;
    getContractFactory(
      name: "CoverPoolEvents",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolEvents__factory>;
    getContractFactory(
      name: "CoverPoolStorage",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolStorage__factory>;
    getContractFactory(
      name: "CoverPoolView",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolView__factory>;
    getContractFactory(
      name: "TwapOracle",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.TwapOracle__factory>;
    getContractFactory(
      name: "CoverPool",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPool__factory>;
    getContractFactory(
      name: "CoverPoolFactory",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolFactory__factory>;
    getContractFactory(
      name: "CoverPoolUtils",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolUtils__factory>;
    getContractFactory(
      name: "ICoverPool",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ICoverPool__factory>;
    getContractFactory(
      name: "ICoverPoolFactory",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ICoverPoolFactory__factory>;
    getContractFactory(
      name: "IPoolsharkUtils",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IPoolsharkUtils__factory>;
    getContractFactory(
      name: "IERC20",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IERC20__factory>;
    getContractFactory(
      name: "IPositionManager",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IPositionManager__factory>;
    getContractFactory(
      name: "IRangeFactory",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IRangeFactory__factory>;
    getContractFactory(
      name: "IRangePool",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IRangePool__factory>;
    getContractFactory(
      name: "IDyDxMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IDyDxMath__factory>;
    getContractFactory(
      name: "IFullPrecisionMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IFullPrecisionMath__factory>;
    getContractFactory(
      name: "IMathUtils",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IMathUtils__factory>;
    getContractFactory(
      name: "IRebaseLibrary",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IRebaseLibrary__factory>;
    getContractFactory(
      name: "ISafeCast",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ISafeCast__factory>;
    getContractFactory(
      name: "ISwapLib",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ISwapLib__factory>;
    getContractFactory(
      name: "ITwapOracle",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.ITwapOracle__factory>;
    getContractFactory(
      name: "IUnsafeMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.IUnsafeMath__factory>;
    getContractFactory(
      name: "DyDxMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.DyDxMath__factory>;
    getContractFactory(
      name: "FullPrecisionMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.FullPrecisionMath__factory>;
    getContractFactory(
      name: "Positions",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Positions__factory>;
    getContractFactory(
      name: "TickMath",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.TickMath__factory>;
    getContractFactory(
      name: "Ticks",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Ticks__factory>;
    getContractFactory(
      name: "RangeFactoryMock",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.RangeFactoryMock__factory>;
    getContractFactory(
      name: "RangePoolMock",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.RangePoolMock__factory>;
    getContractFactory(
      name: "Token20",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.Token20__factory>;
    getContractFactory(
      name: "CoverMiscErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverMiscErrors__factory>;
    getContractFactory(
      name: "CoverPoolErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolErrors__factory>;
    getContractFactory(
      name: "CoverPoolFactoryErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPoolFactoryErrors__factory>;
    getContractFactory(
      name: "CoverPositionErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverPositionErrors__factory>;
    getContractFactory(
      name: "CoverTicksErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverTicksErrors__factory>;
    getContractFactory(
      name: "CoverTransferErrors",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.CoverTransferErrors__factory>;
    getContractFactory(
      name: "MathUtils",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.MathUtils__factory>;
    getContractFactory(
      name: "SafeCast",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SafeCast__factory>;
    getContractFactory(
      name: "SafeTransfers",
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<Contracts.SafeTransfers__factory>;

    getContractAt(
      name: "ERC20",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC20>;
    getContractAt(
      name: "ERC20Burnable",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ERC20Burnable>;
    getContractAt(
      name: "IERC20Metadata",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20Metadata>;
    getContractAt(
      name: "IERC20",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20>;
    getContractAt(
      name: "CoverPoolEvents",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolEvents>;
    getContractAt(
      name: "CoverPoolStorage",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolStorage>;
    getContractAt(
      name: "CoverPoolView",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolView>;
    getContractAt(
      name: "TwapOracle",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.TwapOracle>;
    getContractAt(
      name: "CoverPool",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPool>;
    getContractAt(
      name: "CoverPoolFactory",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolFactory>;
    getContractAt(
      name: "CoverPoolUtils",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolUtils>;
    getContractAt(
      name: "ICoverPool",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ICoverPool>;
    getContractAt(
      name: "ICoverPoolFactory",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ICoverPoolFactory>;
    getContractAt(
      name: "IPoolsharkUtils",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IPoolsharkUtils>;
    getContractAt(
      name: "IERC20",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IERC20>;
    getContractAt(
      name: "IPositionManager",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IPositionManager>;
    getContractAt(
      name: "IRangeFactory",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IRangeFactory>;
    getContractAt(
      name: "IRangePool",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IRangePool>;
    getContractAt(
      name: "IDyDxMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IDyDxMath>;
    getContractAt(
      name: "IFullPrecisionMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IFullPrecisionMath>;
    getContractAt(
      name: "IMathUtils",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IMathUtils>;
    getContractAt(
      name: "IRebaseLibrary",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IRebaseLibrary>;
    getContractAt(
      name: "ISafeCast",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ISafeCast>;
    getContractAt(
      name: "ISwapLib",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ISwapLib>;
    getContractAt(
      name: "ITwapOracle",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.ITwapOracle>;
    getContractAt(
      name: "IUnsafeMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.IUnsafeMath>;
    getContractAt(
      name: "DyDxMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.DyDxMath>;
    getContractAt(
      name: "FullPrecisionMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.FullPrecisionMath>;
    getContractAt(
      name: "Positions",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Positions>;
    getContractAt(
      name: "TickMath",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.TickMath>;
    getContractAt(
      name: "Ticks",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Ticks>;
    getContractAt(
      name: "RangeFactoryMock",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.RangeFactoryMock>;
    getContractAt(
      name: "RangePoolMock",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.RangePoolMock>;
    getContractAt(
      name: "Token20",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.Token20>;
    getContractAt(
      name: "CoverMiscErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverMiscErrors>;
    getContractAt(
      name: "CoverPoolErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolErrors>;
    getContractAt(
      name: "CoverPoolFactoryErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPoolFactoryErrors>;
    getContractAt(
      name: "CoverPositionErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverPositionErrors>;
    getContractAt(
      name: "CoverTicksErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverTicksErrors>;
    getContractAt(
      name: "CoverTransferErrors",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.CoverTransferErrors>;
    getContractAt(
      name: "MathUtils",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.MathUtils>;
    getContractAt(
      name: "SafeCast",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SafeCast>;
    getContractAt(
      name: "SafeTransfers",
      address: string,
      signer?: ethers.Signer
    ): Promise<Contracts.SafeTransfers>;

    // default types
    getContractFactory(
      name: string,
      signerOrOptions?: ethers.Signer | FactoryOptions
    ): Promise<ethers.ContractFactory>;
    getContractFactory(
      abi: any[],
      bytecode: ethers.utils.BytesLike,
      signer?: ethers.Signer
    ): Promise<ethers.ContractFactory>;
    getContractAt(
      nameOrAbi: string | any[],
      address: string,
      signer?: ethers.Signer
    ): Promise<ethers.Contract>;
  }
}
