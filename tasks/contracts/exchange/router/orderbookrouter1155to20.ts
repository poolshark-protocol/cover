import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ERC20, OrderBook20 } from "../../../../typechain";
import { task } from "hardhat/config";
import { getWalletAddress, getNonce, fundUser, readDeploymentsFile } from "../../../utils";
import { LIMIT_ORDER_20 } from "../../../constants/taskNames";
import { Contract } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const { expect } = require("chai");