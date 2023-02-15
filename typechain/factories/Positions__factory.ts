/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Positions, PositionsInterface } from "../Positions";

const _abi = [
  {
    inputs: [],
    name: "InvalidClaimTick",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidLowerTick",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidPositionAmount",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidPositionBoundsOrder",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidPositionBoundsTwap",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidUpperTick",
    type: "error",
  },
  {
    inputs: [],
    name: "LiquidityOverflow",
    type: "error",
  },
  {
    inputs: [],
    name: "NotEnoughPositionLiquidity",
    type: "error",
  },
  {
    inputs: [],
    name: "NotImplementedYet",
    type: "error",
  },
  {
    inputs: [],
    name: "PositionNotUpdated",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickClaimedAt",
    type: "error",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "int24",
            name: "lowerOld",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "lower",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "upper",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "upperOld",
            type: "int24",
          },
          {
            internalType: "bool",
            name: "zeroForOne",
            type: "bool",
          },
          {
            internalType: "uint128",
            name: "amount",
            type: "uint128",
          },
          {
            components: [
              {
                internalType: "uint8",
                name: "unlocked",
                type: "uint8",
              },
              {
                internalType: "uint16",
                name: "swapFee",
                type: "uint16",
              },
              {
                internalType: "int16",
                name: "tickSpread",
                type: "int16",
              },
              {
                internalType: "uint16",
                name: "twapLength",
                type: "uint16",
              },
              {
                internalType: "uint16",
                name: "auctionLength",
                type: "uint16",
              },
              {
                internalType: "int24",
                name: "latestTick",
                type: "int24",
              },
              {
                internalType: "uint32",
                name: "genesisBlock",
                type: "uint32",
              },
              {
                internalType: "uint32",
                name: "lastBlock",
                type: "uint32",
              },
              {
                internalType: "uint32",
                name: "auctionStart",
                type: "uint32",
              },
              {
                internalType: "uint32",
                name: "accumEpoch",
                type: "uint32",
              },
              {
                internalType: "uint128",
                name: "liquidityGlobal",
                type: "uint128",
              },
              {
                internalType: "uint160",
                name: "latestPrice",
                type: "uint160",
              },
              {
                internalType: "contract IRangePool",
                name: "inputPool",
                type: "IRangePool",
              },
            ],
            internalType: "struct ICoverPoolStructs.GlobalState",
            name: "state",
            type: "tuple",
          },
        ],
        internalType: "struct ICoverPoolStructs.ValidateParams",
        name: "params",
        type: "tuple",
      },
    ],
    name: "validate",
    outputs: [
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
      {
        internalType: "uint128",
        name: "",
        type: "uint128",
      },
      {
        internalType: "uint256",
        name: "liquidityMinted",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x61338461003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100565760003560e01c8063021a3af01461005b5780632060836a14610092578063576613d8146100b2578063c92deb3a14610109575b600080fd5b81801561006757600080fd5b5061007b610076366004612a3e565b610136565b604051610089929190612c03565b60405180910390f35b81801561009e57600080fd5b5061007b6100ad366004612c28565b61068f565b6100c56100c0366004612d10565b610b01565b60408051600297880b815295870b602087015293860b93850193909352930b60608301526001600160801b03909216608082015260a081019190915260c001610089565b81801561011557600080fd5b50610129610124366004612dae565b611263565b6040516100899190612e97565b600061014061272a565b604080516060810180835285516001600160a01b03908116600090815260208c8152858220818a018051600290810b85529183528784208b890151830b855283528784206101008801895280546001600160801b03808216895263ffffffff600160801b928390041660808b0152600183015490971660a08a01529083015480871660c08a01520490941660e08701529385529151855163986cfba360e01b8152930b600484015293518184019273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9263986cfba3926024808401938290030181865af4158015610229573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061024d9190612eb7565b6001600160a01b03168152604080870151905163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156102b7573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102db9190612eb7565b6001600160a01b0316815250905083608001516001600160801b031660000361030b576000859250925050610685565b80515160808501516001600160801b039182169116111561033f5760405163193d143560e11b815260040160405180910390fd5b836060015161039757836020015160020b8560a0015160020b1380610392575080516020908101518582015160020b60009081529188905260409091205463ffffffff918216600160301b909104909116115b6103e1565b836040015160020b8560a0015160020b12806103e15750805160209081015160408087015160020b6000908152928990529091205463ffffffff918216600160301b909104909116115b156103ff57604051632d59207760e11b815260040160405180910390fd5b6020840151604080860151608087015160608801519251636e9fd64960e11b815273__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__9463dd3fac9294610455948e948e948e9493906001908190600401612ed4565b60006040518083038186803b15801561046d57600080fd5b505af4158015610481573d6000803e3d6000fd5b50505050836060015161051b5773__$357eccfa53a4e88c122661903e0e603301$__63580680d88560800151836020015184604001516040518463ffffffff1660e01b81526004016104d593929190612f3b565b602060405180830381865af41580156104f2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105169190612f65565b6105a3565b73__$357eccfa53a4e88c122661903e0e603301$__633a39264c8560800151836020015184604001516040518463ffffffff1660e01b815260040161056293929190612f3b565b602060405180830381865af415801561057f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105a39190612f65565b815160800180516105b5908390612f94565b6001600160801b03169052506080840151815180516105d5908390612fbf565b6001600160801b03908116909152915185516001600160a01b03908116600090815260208c81526040808320828b0151600290810b8552908352818420828c0151820b855283529281902085518154938701519089166001600160a01b031994851617600160801b63ffffffff9092168202178255918601516001820180549094169516949094179091556060840151608094850151908716961602949094179301929092555083015191508390505b9550959350505050565b600061069961272a565b60408051606080820180845286516001600160a01b03908116600090815260208d81528682208a88018051600290810b8552918352888420968c0151820b84529582528783206101008801895280546001600160801b038082168852600160801b9182900463ffffffff1660808b0152600183015490961660a08a01529082015480861660c08a01520490931660e08701529285529251945163986cfba360e01b815294900b600485015290929082019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610786573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107aa9190612eb7565b6001600160a01b03168152606086015160405163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610814573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108389190612eb7565b6001600160a01b031681525090508360c001516001600160801b0316600003610868576000859250925050610685565b8051516001600160801b03166000036108c257610120850151815163ffffffff90911660209091015260a08401516108a45780602001516108aa565b80604001515b81516001600160a01b03909116604090910152610983565b8360a0015161091a57836040015160020b8560a0015160020b13806109155750805160209081015160408087015160020b6000908152928990529091205463ffffffff918216600160301b909104909116115b610965565b836060015160020b8560a0015160020b128061096557508051602090810151606086015160020b60009081529188905260409091205463ffffffff918216600160301b909104909116115b1561098357604051632d59207760e11b815260040160405180910390fd5b73__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__63cdb98d07888888886020015189604001518a608001518b606001518c60c001518d60a001516040518a63ffffffff1660e01b81526004016109e299989796959493929190612fe7565b6101a060405180830381865af4158015610a00573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610a249190613094565b60c0850151825180519297509091610a3d908390612f94565b6001600160801b03908116909152915185516001600160a01b03908116600090815260208c81526040808320818b0151600290810b85529083528184206060808d0151830b865290845293829020865181549488015163ffffffff16600160801b9081026001600160a01b0319968716928c16929092179190911782559287015160018201805491909716941693909317909455918401516080909401518616909102929094169190911792019190915550505060c0810151829550959350505050565b6000806000806000808660c001516040015160010b8760200151610b2591906131a8565b60020b15610b46576040516347b567bd60e01b815260040160405180910390fd5b620d89e71960020b876020015160020b1215610b75576040516347b567bd60e01b815260040160405180910390fd5b8660c001516040015160010b8760400151610b9091906131a8565b60020b15610bb157604051630cda75cf60e41b815260040160405180910390fd5b610bbe620d89e7196131ca565b60020b876040015160020b1315610be857604051630cda75cf60e41b815260040160405180910390fd5b8660a001516001600160801b0316600003610c1657604051630bc9d91360e21b815260040160405180910390fd5b866040015160020b876020015160020b121580610c415750866060015160020b876000015160020b12155b15610c5f5760405163119de2e360e21b815260040160405180910390fd5b866080015115610ca0578660c0015160a0015160020b876020015160020b12610c9b57604051630f4b1dd760e21b815260040160405180910390fd5b610cd2565b8660c0015160a0015160020b876040015160020b13610cd257604051630f4b1dd760e21b815260040160405180910390fd5b602087015160405163986cfba360e01b815260029190910b600482015260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610d2e573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610d529190612eb7565b6001600160a01b03169050600073__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba38a604001516040518263ffffffff1660e01b8152600401610da3919060029190910b815260200190565b602060405180830381865af4158015610dc0573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610de49190612eb7565b6001600160a01b0316905073__$357eccfa53a4e88c122661903e0e603301$__63aec6cbfe83838c60800151610e1a5784610e1c565b855b8d60800151610e38578d60a001516001600160801b0316610e3b565b60005b8e60800151610e4b576000610e5a565b8e60a001516001600160801b03165b6040516001600160e01b031960e088901b1681526004810195909552602485019390935260448401919091526064830152608482015260a401602060405180830381865af4158015610eb0573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610ed49190612f65565b9250886080015115611060578860c0015160a0015160020b896040015160020b1261105b5760c0890151604081015160a090910151610f169160010b906131ec565b600290810b60408b810182905260c08c015160a0015190920b60608c0152905163986cfba360e01b8152600481019190915260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610f87573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610fab9190612eb7565b604051630e8e499360e21b8152600481018690526001600160a01b03919091166024820181905260448201849052915073__$357eccfa53a4e88c122661903e0e603301$__90633a39264c90606401602060405180830381865af4158015611017573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061103b9190612f65565b8a60a00181815161104c9190612fbf565b6001600160801b031690525090505b6111d8565b8860c0015160a0015160020b896020015160020b136111d85760c0890151604081015160a0909101516110969160010b90613234565b600290810b60208b0181905260c08b015160a0015190910b8a5260405163986cfba360e01b8152600481019190915260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015611104573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906111289190612eb7565b604051630b00d01b60e31b815260048101869052602481018590526001600160a01b039190911660448201819052915073__$357eccfa53a4e88c122661903e0e603301$__9063580680d890606401602060405180830381865af4158015611194573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906111b89190612f65565b8a60a0018181516111c99190612fbf565b6001600160801b031690525091505b6f7fffffffffffffffffffffffffffffff8311156112095760405163581a12d760e11b815260040160405180910390fd5b886040015160020b896020015160020b0361123757604051630f4b1dd760e21b815260040160405180910390fd5b505086516020880151604089015160608a015160a0909a0151929a919990985096509094509092509050565b61126b61272a565b60408051610120810180835284516001600160a01b03908116600090815260208c81528582208189018051600290810b85529183528784208a890151830b855283528784206101c08801895280546001600160801b03808216895263ffffffff600160801b92839004166101408b015260018301549097166101608a0152908301548087166101808a0152049094166101a08701529385529151855163986cfba360e01b8152930b600484015293518184019273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9263986cfba3926024808401938290030181865af4158015611359573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061137d9190612eb7565b6001600160a01b03168152604080860151905163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156113e7573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061140b9190612eb7565b6001600160a01b03168152606085015160405163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015611475573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906114999190612eb7565b6001600160a01b03168152606085810151600290810b600090815260208b8152604080832081518087018352905480860b82526301000000810490950b81840152600160301b90940463ffffffff1684820152908501929092526001918401829052918301528654600160801b90046001600160801b03908116608084015260a0909201819052825151929350911690036115605760008360a00151600f0b13156115575760405163193d143560e11b815260040160405180910390fd5b84915050612720565b826080015161158f5780606001516001600160a01b03168160000151604001516001600160a01b0316116115b1565b80606001516001600160a01b03168160000151604001516001600160a01b0316105b80156115cb57508460a0015160020b836060015160020b14155b156115e957604051638c39242d60e01b815260040160405180910390fd5b826020015160020b836060015160020b12806116125750826040015160020b836060015160020b135b1561163057604051638c39242d60e01b815260040160405180910390fd5b600083608001516116c9578151805160409182015160608501519251630e8e499360e21b815273__$357eccfa53a4e88c122661903e0e603301$__93633a39264c93611683939092909190600401612f3b565b602060405180830381865af41580156116a0573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906116c49190612f65565b611752565b8151805160608401516040928301519251630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9363580680d893611711939092909190600401612f3b565b602060405180830381865af415801561172e573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906117529190612f65565b905080826000015160600181815161176a9190612f94565b6001600160801b031690525050608083015161178a578260400151611790565b82602001515b60020b836060015160020b036119465780600001516020015163ffffffff1681608001516040015163ffffffff16116117dc57604051632d59207760e11b815260040160405180910390fd5b82608001516117f357600060c082018190526117fd565b600060a082018190525b50606083018051600290810b600090815260208a90526040808220600101549351830b825290200154670de0b6b3a764000091611858916001600160801b03600160801b92839004169167ffffffffffffffff91041661327b565b611862919061329a565b606084015160020b6000908152602089905260409020600101546118969190600160801b90046001600160801b03166132ae565b6001600160801b0390811660e0830152606084018051600290810b600090815260208b90526040808220600101549351830b825290200154670de0b6b3a7640000926118fb92600160801b90041690600160c01b900467ffffffffffffffff1661327b565b611905919061329a565b6060840151600290810b600090815260208a905260409020015461193291906001600160801b03166132ae565b6001600160801b0316610100820152612088565b6000836080015161197f57608082015160209081015160020b6000908152908890526040902054600160301b900463ffffffff166119a5565b60808201515160020b600090815260208890526040902054600160301b900463ffffffff165b905081600001516020015163ffffffff168163ffffffff1611156119dc57604051632d59207760e11b815260040160405180910390fd5b60008460a00151600f0b1315611a89578360800151611a31578151602090810151608084015182015160020b60009081529189905260409091205463ffffffff918216600160301b9091049091161115611a34565b60015b151560a08301526080840151611a4b576001611a81565b815160209081015160808401515160020b60009081529189905260409091205463ffffffff918216600160301b90910490911611155b151560c08301525b8360800151611a9c578360200151611aa2565b83604001515b60020b846060015160020b14611b4057606084015160020b60009081526020899052604090206001015460e083018051600160801b9092046001600160801b031691611aef908390612f94565b6001600160801b039081169091526060860151600290810b600090815260208c905260409020015461010085018051919092169250611b2f908390612f94565b6001600160801b0316905250611c3c565b606084018051600290810b600090815260208b90526040808220830154935190920b81522060010154670de0b6b3a764000091611b9b9167ffffffffffffffff600160801b9283900416916001600160801b039104166132c5565b611ba591906132f4565b8260e001818151611bb69190612f94565b6001600160801b03908116909152606086018051600290810b600090815260208d905260408082208301549351830b825290200154670de0b6b3a76400009350611c1392600160c01b90920467ffffffffffffffff1691166132c5565b611c1d91906132f4565b8261010001818151611c2f9190612f94565b6001600160801b03169052505b836060015160020b8660a0015160020b03612086578360800151611cf05781515160608301516001870154604051630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9363580680d893611caa93919290916001600160a01b031690600401612f3b565b602060405180830381865af4158015611cc7573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611ceb9190612f65565b611d82565b81515160018601546060840151604051630e8e499360e21b815273__$357eccfa53a4e88c122661903e0e603301$__93633a39264c93611d419391926001600160a01b039091169190600401612f3b565b602060405180830381865af4158015611d5e573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611d829190612f65565b82516080018051611d94908390612f94565b6001600160801b03169052506080840151600090611e455773__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3886040015160010b8960a00151611ddd9190613234565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015611e1c573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611e409190612eb7565b611ed9565b73__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3886040015160010b8960a00151611e7691906131ec565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015611eb5573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611ed99190612eb7565b6001600160a01b03811660608501526080860151909150611f85578251516001870154604051630e8e499360e21b815273__$357eccfa53a4e88c122661903e0e603301$__92633a39264c92611f3f926001600160a01b03909116908690600401612f3b565b602060405180830381865af4158015611f5c573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190611f809190612f65565b61200f565b8251516001870154604051630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9263580680d892611fce9286916001600160a01b031690600401612f3b565b602060405180830381865af4158015611feb573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061200f9190612f65565b83516060018051612021908390612f94565b6001600160801b03169052505060a08401516000600f9190910b13156120865760a0840151855486906000906120619084906001600160801b0316612fbf565b92506101000a8154816001600160801b0302191690836001600160801b031602179055505b505b60008360a00151600f0b13156121d557826080015161212e5773__$357eccfa53a4e88c122661903e0e603301$__63580680d88460a00151836060015184604001516040518463ffffffff1660e01b81526004016120e893929190612f3b565b602060405180830381865af4158015612105573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906121299190612f65565b6121b6565b73__$357eccfa53a4e88c122661903e0e603301$__633a39264c8460a00151836020015184606001516040518463ffffffff1660e01b815260040161217593929190612f3b565b602060405180830381865af4158015612192573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906121b69190612f65565b815160800180516121c8908390612f94565b6001600160801b03169052505b6101008101516001600160801b03161561229f5761010081015181515160405163554d048960e11b81526001600160801b03928316600482015291166024820152600160601b604482015273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af415801561225c573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906122809190612f65565b81516080018051612292908390612f94565b6001600160801b03169052505b60e08101516001600160801b0316156123725760e081015181515160405163554d048960e11b81526001600160801b03928316600482015291166024820152600160601b604482015273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015612324573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906123489190612f65565b61235390600161331a565b81516060018051612365908390612fbf565b6001600160801b03169052505b60208501516123889061ffff16620f4240613332565b62ffffff16816000015160600151620f42406123a491906132c5565b6123ae91906132f4565b81516001600160801b0390911660609182015260a086015190840151600290810b91900b146123e15780606001516123f0565b60018401546001600160a01b03165b81516001600160a01b0390911660409091015260a08301516000600f9190910b131561253a57826080015161242957826020015161242f565b82604001515b60020b836060015160020b1461246257826080015161245657600060a08201819052612460565b600060c082018190525b505b73__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__63dd3fac928888888760800151612492578760600151612498565b87602001515b88608001516124ab5788604001516124b1565b88606001515b8960a001518a608001518960a001518a60c001516040518a63ffffffff1660e01b81526004016124e999989796959493929190612ed4565b60006040518083038186803b15801561250157600080fd5b505af4158015612515573d6000803e3d6000fd5b5050505060a08301518151805161252d908390612fbf565b6001600160801b03169052505b826080015161255a57826020015160020b836060015160020b141561256d565b826040015160020b836060015160020b14155b156125c85782516001600160a01b031660009081526020898152604080832082870151600290810b855290835281842082880151820b8552909252822080546001600160a01b03199081168255600182018054909116905501555b826080015161267757805183516001600160a01b03908116600090815260208b815260408083206060808a0151600290810b8652918452828520838b0151830b8652845293829020865181549488015163ffffffff16600160801b9081026001600160a01b03199687166001600160801b03938416171783559388015160018301805491909816951694909417909555928501516080909501518216029316929092179181019190915561271a565b805183516001600160a01b03908116600090815260208b8152604080832082890151600290810b85529083528184206060808b0151830b865290845293829020865181549488015163ffffffff16600160801b9081026001600160a01b03199687166001600160801b0393841617178355938801516001830180549190981695169490941790955592850151608090950151821602931692909217918101919091555b50849150505b9695505050505050565b604080516101a081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e08101829052610100810182905261012081018290526101408101829052610160810182905261018081019190915290565b6040516101a0810167ffffffffffffffff811182821017156127c857634e487b7160e01b600052604160045260246000fd5b60405290565b60405160a0810167ffffffffffffffff811182821017156127c857634e487b7160e01b600052604160045260246000fd5b60405160e0810167ffffffffffffffff811182821017156127c857634e487b7160e01b600052604160045260246000fd5b60405160c0810167ffffffffffffffff811182821017156127c857634e487b7160e01b600052604160045260246000fd5b60ff8116811461287057600080fd5b50565b803561287e81612861565b919050565b61ffff8116811461287057600080fd5b803561287e81612883565b8060010b811461287057600080fd5b803561287e8161289e565b8060020b811461287057600080fd5b803561287e816128b8565b63ffffffff8116811461287057600080fd5b803561287e816128d2565b6001600160801b038116811461287057600080fd5b803561287e816128ef565b6001600160a01b038116811461287057600080fd5b803561287e8161290f565b60006101a0828403121561294257600080fd5b61294a612796565b905061295582612873565b815261296360208301612893565b6020820152612974604083016128ad565b604082015261298560608301612893565b606082015261299660808301612893565b60808201526129a760a083016128c7565b60a08201526129b860c083016128e4565b60c08201526129c960e083016128e4565b60e08201526101006129dc8184016128e4565b908201526101206129ee8382016128e4565b90820152610140612a00838201612904565b90820152610160612a12838201612924565b90820152610180612a24838201612924565b9082015292915050565b8035801515811461287e57600080fd5b60008060008060008587036102a0811215612a5857600080fd5b863595506020870135945060408701359350612a77886060890161292f565b925060a06101ff1982011215612a8c57600080fd5b50612a956127ce565b610200870135612aa48161290f565b8152610220870135612ab5816128b8565b6020820152610240870135612ac9816128b8565b6040820152612adb6102608801612a2e565b6060820152610280870135612aef816128ef565b6080820152949793965091945092919050565b805160ff1682526020810151612b1e602084018261ffff169052565b506040810151612b33604084018260010b9052565b506060810151612b49606084018261ffff169052565b506080810151612b5f608084018261ffff169052565b5060a0810151612b7460a084018260020b9052565b5060c0810151612b8c60c084018263ffffffff169052565b5060e0810151612ba460e084018263ffffffff169052565b506101008181015163ffffffff908116918401919091526101208083015190911690830152610140808201516001600160801b031690830152610160808201516001600160a01b03908116918401919091526101809182015116910152565b6001600160801b03831681526101c08101612c216020830184612b02565b9392505050565b60008060008060008587036102e0811215612c4257600080fd5b863595506020870135945060408701359350612c61886060890161292f565b925060e06101ff1982011215612c7657600080fd5b50612c7f6127ff565b610200870135612c8e8161290f565b8152610220870135612c9f816128b8565b6020820152610240870135612cb3816128b8565b6040820152610260870135612cc7816128b8565b6060820152612cd961028088016128c7565b6080820152612ceb6102a08801612a2e565b60a0820152612cfd6102c08801612904565b60c0820152809150509295509295909350565b60006102608284031215612d2357600080fd5b612d2b6127ff565b8235612d36816128b8565b81526020830135612d46816128b8565b60208201526040830135612d59816128b8565b60408201526060830135612d6c816128b8565b6060820152612d7d60808401612a2e565b608082015260a0830135612d90816128ef565b60a0820152612da28460c0850161292f565b60c08201529392505050565b6000806000806000808688036102e0811215612dc957600080fd5b873596506020880135955060408801359450612de88960608a0161292f565b9350610200880135925060c061021f1982011215612e0557600080fd5b50612e0e612830565b610220880135612e1d8161290f565b8152610240880135612e2e816128b8565b6020820152610260880135612e42816128b8565b6040820152610280880135612e56816128b8565b6060820152612e686102a08901612a2e565b60808201526102c088013580600f0b8114612e8257600080fd5b8060a083015250809150509295509295509295565b6101a08101612ea68284612b02565b92915050565b805161287e8161290f565b600060208284031215612ec957600080fd5b8151612c218161290f565b898152602081018990526102a08101612ef0604083018a612b02565b600297880b6101e08301529590960b6102008701526001600160801b039390931661022086015290151561024085015215156102608401521515610280909201919091529392505050565b6001600160801b039390931683526001600160a01b03918216602084015216604082015260600190565b600060208284031215612f7757600080fd5b5051919050565b634e487b7160e01b600052601160045260246000fd5b60006001600160801b03808316818516808303821115612fb657612fb6612f7e565b01949350505050565b60006001600160801b0383811690831681811015612fdf57612fdf612f7e565b039392505050565b898152602081018990526102a08101613003604083018a612b02565b8760020b6101e08301528660020b6102008301528560020b6102208301528460020b6102408301526001600160801b0384166102608301528215156102808301529a9950505050505050505050565b805161287e81612861565b805161287e81612883565b805161287e8161289e565b805161287e816128b8565b805161287e816128d2565b805161287e816128ef565b60006101a082840312156130a757600080fd5b6130af612796565b6130b883613052565b81526130c66020840161305d565b60208201526130d760408401613068565b60408201526130e86060840161305d565b60608201526130f96080840161305d565b608082015261310a60a08401613073565b60a082015261311b60c0840161307e565b60c082015261312c60e0840161307e565b60e082015261010061313f81850161307e565b9082015261012061315184820161307e565b90820152610140613163848201613089565b90820152610160613175848201612eac565b90820152610180613187848201612eac565b908201529392505050565b634e487b7160e01b600052601260045260246000fd5b60008260020b806131bb576131bb613192565b808360020b0791505092915050565b60008160020b627fffff1981036131e3576131e3612f7e565b60000392915050565b60008160020b8360020b6000811281627fffff190183128115161561321357613213612f7e565b81627fffff01831381161561322a5761322a612f7e565b5090039392505050565b60008160020b8360020b6000821282627fffff0382138115161561325a5761325a612f7e565b82627fffff1903821281161561327257613272612f7e565b50019392505050565b600081600019048311821515161561329557613295612f7e565b500290565b6000826132a9576132a9613192565b500490565b6000828210156132c0576132c0612f7e565b500390565b60006001600160801b03808316818516818304811182151516156132eb576132eb612f7e565b02949350505050565b60006001600160801b038084168061330e5761330e613192565b92169190910492915050565b6000821982111561332d5761332d612f7e565b500190565b600062ffffff83811690831681811015612fdf57612fdf612f7e56fea2646970667358221220fea0b2f27818b6a196b8ecfa39895aeae3beb2f1b4abaac55fa3c3bf2b8bc72664736f6c634300080d0033";

type PositionsConstructorParams =
  | [linkLibraryAddresses: PositionsLibraryAddresses, signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: PositionsConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => {
  return (
    typeof xs[0] === "string" ||
    (Array.isArray as (arg: any) => arg is readonly any[])(xs[0]) ||
    "_isInterface" in xs[0]
  );
};

export class Positions__factory extends ContractFactory {
  constructor(...args: PositionsConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      const [linkLibraryAddresses, signer] = args;
      super(
        _abi,
        Positions__factory.linkBytecode(linkLibraryAddresses),
        signer
      );
    }
  }

  static linkBytecode(linkLibraryAddresses: PositionsLibraryAddresses): string {
    let linkedBytecode = _bytecode;

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$b52f7ddb7db4526c8b5c81c46a9292f776\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/TickMath.sol:TickMath"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$dc25dd3a5fe6a540f35c01c335c2ccfd23\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/Ticks.sol:Ticks"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$357eccfa53a4e88c122661903e0e603301\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/DyDxMath.sol:DyDxMath"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$1b9fef1800622f5f6a93914ffdeb7ba32f\\$__", "g"),
      linkLibraryAddresses[
        "contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"
      ]
        .replace(/^0x/, "")
        .toLowerCase()
    );

    return linkedBytecode;
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<Positions> {
    return super.deploy(overrides || {}) as Promise<Positions>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): Positions {
    return super.attach(address) as Positions;
  }
  connect(signer: Signer): Positions__factory {
    return super.connect(signer) as Positions__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): PositionsInterface {
    return new utils.Interface(_abi) as PositionsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): Positions {
    return new Contract(address, _abi, signerOrProvider) as Positions;
  }
}

export interface PositionsLibraryAddresses {
  ["contracts/libraries/TickMath.sol:TickMath"]: string;
  ["contracts/libraries/Ticks.sol:Ticks"]: string;
  ["contracts/libraries/DyDxMath.sol:DyDxMath"]: string;
  ["contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"]: string;
}
