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
  "0x6136f161003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100565760003560e01c8063021a3af01461005b5780632060836a14610092578063576613d8146100b2578063c92deb3a14610109575b600080fd5b81801561006757600080fd5b5061007b610076366004612db1565b610136565b604051610089929190612f76565b60405180910390f35b81801561009e57600080fd5b5061007b6100ad366004612f9b565b6106cb565b6100c56100c0366004613083565b610b62565b60408051600297880b815295870b602087015293860b93850193909352930b60608301526001600160801b03909216608082015260a081019190915260c001610089565b81801561011557600080fd5b50610129610124366004613121565b6112c4565b6040516100899190613204565b6000610140612a9d565b604080516060810180835285516001600160a01b03908116600090815260208c8152858220818a018051600290810b85529183528784208b890151830b8552835287842061012088018952805463ffffffff811688526001600160801b03600160201b909104811660808a0152600182015480821660a08b0152600160801b9004811660c08a0152818401541660e0890152600301549094166101008701529385529151855163986cfba360e01b8152930b600484015293518184019273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9263986cfba3926024808401938290030181865af4158015610238573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061025c9190613224565b6001600160a01b03168152604080870151905163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156102c6573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102ea9190613224565b6001600160a01b0316815250905083608001516001600160801b031660000361031a5760008592509250506106c1565b8060000151602001516001600160801b031684608001516001600160801b031611156103595760405163193d143560e11b815260040160405180910390fd5b83606001516103ad57836020015160020b8560a0015160020b13806103a8575080515160208086015160020b600090815290889052604090205463ffffffff918216600160301b909104909116115b6103f1565b836040015160020b8560a0015160020b12806103f1575080515160408086015160020b60009081526020899052205463ffffffff918216600160301b909104909116115b1561040f57604051632d59207760e11b815260040160405180910390fd5b6020840151604080860151608087015160608801519251636e9fd64960e11b815273__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__9463dd3fac9294610465948e948e948e9493906001908190600401613241565b60006040518083038186803b15801561047d57600080fd5b505af4158015610491573d6000803e3d6000fd5b50505050836060015161052b5773__$357eccfa53a4e88c122661903e0e603301$__63580680d88560800151836020015184604001516040518463ffffffff1660e01b81526004016104e5939291906132a8565b602060405180830381865af4158015610502573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061052691906132d2565b6105b3565b73__$357eccfa53a4e88c122661903e0e603301$__633a39264c8560800151836020015184604001516040518463ffffffff1660e01b8152600401610572939291906132a8565b602060405180830381865af415801561058f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906105b391906132d2565b815160600180516105c5908390613301565b6001600160801b03169052506080840151815160200180516105e890839061332c565b6001600160801b03908116909152915185516001600160a01b03908116600090815260208c81526040808320828b0151600290810b8552908352818420828c0151820b855283529281902085518154938701518916600160201b026001600160a01b031994851663ffffffff909216919091171781559085015160608601518816600160801b029088161760018201556080808601519382018054949098166001600160801b0319949094169390931790965560a090930151600390950180549590921694909216939093179092555083015191508390505b9550959350505050565b60006106d5612a9d565b60408051606080820180845286516001600160a01b03908116600090815260208d81528682208a88018051600290810b8552918352888420968c0151820b845295825287832061012088018952805463ffffffff81168752600160201b90046001600160801b0390811660808a0152600182015480821660a08b0152600160801b9004811660c08a0152818301541660e0890152600301549093166101008701529285529251945163986cfba360e01b815294900b600485015290929082019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156107d1573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906107f59190613224565b6001600160a01b03168152606086015160405163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af415801561085f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108839190613224565b6001600160a01b031681525090508360c001516001600160801b03166000036108b35760008592509250506106c1565b8051602001516001600160801b031660000361090c57610120850151815163ffffffff909116905260a08401516108ee5780602001516108f4565b80604001515b81516001600160a01b0390911660a0909101526109c2565b8360a0015161095e57836040015160020b8560a0015160020b1380610959575080515160408086015160020b60009081526020899052205463ffffffff918216600160301b909104909116115b6109a4565b836060015160020b8560a0015160020b12806109a45750805151606085015160020b60009081526020889052604090205463ffffffff918216600160301b909104909116115b156109c257604051632d59207760e11b815260040160405180910390fd5b73__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__63cdb98d07888888886020015189604001518a608001518b606001518c60c001518d60a001516040518a63ffffffff1660e01b8152600401610a2199989796959493929190613354565b6101a060405180830381865af4158015610a3f573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610a639190613401565b94508360c001518160000151602001818151610a7f9190613301565b6001600160801b03908116909152915185516001600160a01b03908116600090815260208c81526040808320818b0151600290810b85529083528184206060808d0151830b86529084529382902086518154948801518a16600160201b026001600160a01b031995861663ffffffff9092169190911717815591860151938601518816600160801b0293881693909317600182015560808501519281018054939097166001600160801b0319939093169290921790955560a0909201516003909201805492909116919093161790915550505060c0810151829550959350505050565b6000806000806000808660c001516040015160010b8760200151610b869190613515565b60020b15610ba7576040516347b567bd60e01b815260040160405180910390fd5b620d89e71960020b876020015160020b1215610bd6576040516347b567bd60e01b815260040160405180910390fd5b8660c001516040015160010b8760400151610bf19190613515565b60020b15610c1257604051630cda75cf60e41b815260040160405180910390fd5b610c1f620d89e719613537565b60020b876040015160020b1315610c4957604051630cda75cf60e41b815260040160405180910390fd5b8660a001516001600160801b0316600003610c7757604051630bc9d91360e21b815260040160405180910390fd5b866040015160020b876020015160020b121580610ca25750866060015160020b876000015160020b12155b15610cc05760405163119de2e360e21b815260040160405180910390fd5b866080015115610d01578660c0015160a0015160020b876020015160020b12610cfc57604051630f4b1dd760e21b815260040160405180910390fd5b610d33565b8660c0015160a0015160020b876040015160020b13610d3357604051630f4b1dd760e21b815260040160405180910390fd5b602087015160405163986cfba360e01b815260029190910b600482015260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610d8f573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610db39190613224565b6001600160a01b03169050600073__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba38a604001516040518263ffffffff1660e01b8152600401610e04919060029190910b815260200190565b602060405180830381865af4158015610e21573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610e459190613224565b6001600160a01b0316905073__$357eccfa53a4e88c122661903e0e603301$__63aec6cbfe83838c60800151610e7b5784610e7d565b855b8d60800151610e99578d60a001516001600160801b0316610e9c565b60005b8e60800151610eac576000610ebb565b8e60a001516001600160801b03165b6040516001600160e01b031960e088901b1681526004810195909552602485019390935260448401919091526064830152608482015260a401602060405180830381865af4158015610f11573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610f3591906132d2565b92508860800151156110c1578860c0015160a0015160020b896040015160020b126110bc5760c0890151604081015160a090910151610f779160010b90613559565b600290810b60408b810182905260c08c015160a0015190920b60608c0152905163986cfba360e01b8152600481019190915260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015610fe8573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061100c9190613224565b604051630e8e499360e21b8152600481018690526001600160a01b03919091166024820181905260448201849052915073__$357eccfa53a4e88c122661903e0e603301$__90633a39264c90606401602060405180830381865af4158015611078573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061109c91906132d2565b8a60a0018181516110ad919061332c565b6001600160801b031690525090505b611239565b8860c0015160a0015160020b896020015160020b136112395760c0890151604081015160a0909101516110f79160010b906135a1565b600290810b60208b0181905260c08b015160a0015190910b8a5260405163986cfba360e01b8152600481019190915260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015611165573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906111899190613224565b604051630b00d01b60e31b815260048101869052602481018590526001600160a01b039190911660448201819052915073__$357eccfa53a4e88c122661903e0e603301$__9063580680d890606401602060405180830381865af41580156111f5573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061121991906132d2565b8a60a00181815161122a919061332c565b6001600160801b031690525091505b6f7fffffffffffffffffffffffffffffff83111561126a5760405163581a12d760e11b815260040160405180910390fd5b886040015160020b896020015160020b0361129857604051630f4b1dd760e21b815260040160405180910390fd5b505086516020880151604089015160608a015160a0909a0151929a919990985096509094509092509050565b6112cc612a9d565b60408051610140810180835284516001600160a01b03908116600090815260208c81528582208189018051600290810b85529183528784208a890151830b8552835287842061020088018952805463ffffffff811688526001600160801b03600160201b90910481166101608a015260018201548082166101808b0152600160801b900481166101a08a015281840154166101c0890152600301549094166101e08701529385529151855163986cfba360e01b8152930b600484015293518184019273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9263986cfba3926024808401938290030181865af41580156113c9573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906113ed9190613224565b6001600160a01b03168152606085015160405163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015611457573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061147b9190613224565b6001600160a01b03168152604080860151905163986cfba360e01b815260029190910b600482015260209091019073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156114e5573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906115099190613224565b6001600160a01b0316815260200173__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3866080015161155657886040015160010b8960a0015161155191906135a1565b61156d565b886040015160010b8960a0015161156d9190613559565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af41580156115ac573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906115d09190613224565b6001600160a01b0316815260608086018051600290810b600090815260208c815260409182902082518087018452905480850b825263010000008104850b8284015263ffffffff600160301b90910416818401529086015260019085018190529284019290925260a08901519051608090930192820b910b14611654576000611667565b8554600160801b90046001600160801b03165b6001600160801b0316815260200160006001600160801b031681525090508060000151602001516001600160801b03166000036116d35760a08301516001600160801b0316156116ca5760405163193d143560e11b815260040160405180910390fd5b84915050612a93565b826080015161171357826020015160020b836060015160020b14801561170e5750600184015460208201516001600160a01b03908116911614155b611745565b826040015160020b836060015160020b1480156117455750600184015460608201516001600160a01b03908116911614155b801561175e57508460a0015160020b836060015160020b145b1561178e576001840154815160a001516001600160a01b039182169116036117895784915050612a93565b611817565b82608001516117bd5780604001516001600160a01b0316816000015160a001516001600160a01b0316116117df565b80604001516001600160a01b0316816000015160a001516001600160a01b0316105b80156117f957508460a0015160020b836060015160020b14155b1561181757604051638c39242d60e01b815260040160405180910390fd5b826020015160020b836060015160020b12806118405750826040015160020b836060015160020b135b1561185e57604051638c39242d60e01b815260040160405180910390fd5b826080015161188d57806000015160a001516001600160a01b031681604001516001600160a01b0316116118af565b806000015160a001516001600160a01b031681604001516001600160a01b0316105b15611a065760008360800151611951578151602081015160a0909101516040808501519051630e8e499360e21b815273__$357eccfa53a4e88c122661903e0e603301$__93633a39264c9361190b9391929091906004016132a8565b602060405180830381865af4158015611928573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061194c91906132d2565b6119db565b8151602081015160408085015160a0909301519051630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9363580680d89361199a9390926004016132a8565b602060405180830381865af41580156119b7573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906119db91906132d2565b90508082600001516040018181516119f39190613301565b6001600160801b0316905250611aa19050565b8260800151611a3557806000015160a001516001600160a01b031681604001516001600160a01b031610611a57565b806000015160a001516001600160a01b031681604001516001600160a01b0316115b15611aa15760018401546001600160a01b031660408201528051608001518454611a919190600160801b90046001600160801b031661332c565b6001600160801b03166101008201525b8260800151611ab4578260400151611aba565b82602001515b60020b836060015160020b03611c695780515160a08201516040015163ffffffff918216911611611afe57604051632d59207760e11b815260040160405180910390fd5b8260800151611b1557600060e08201819052611b1f565b600060c082018190525b50606083018051600290810b600090815260208a90526040808220600101549351830b825290200154670de0b6b3a764000091611b7a916001600160801b03600160801b92839004169167ffffffffffffffff9104166135e8565b611b849190613607565b606084015160020b600090815260208990526040902060010154611bb89190600160801b90046001600160801b031661361b565b6001600160801b03908116610100830152606084018051600290810b600090815260208b90526040808220600101549351830b825290200154670de0b6b3a764000092611c1e92600160801b90041690600160c01b900467ffffffffffffffff166135e8565b611c289190613607565b6060840151600290810b600090815260208a9052604090200154611c5591906001600160801b031661361b565b6001600160801b031661012082015261232e565b60008360800151611ca25760a082015160209081015160020b6000908152908890526040902054600160301b900463ffffffff16611cc8565b60a08201515160020b600090815260208890526040902054600160301b900463ffffffff165b82515190915063ffffffff9081169082161115611cf857604051632d59207760e11b815260040160405180910390fd5b60a08401516001600160801b031615611da0578360800151611d4d5781515160a083015160209081015160020b600090815290899052604090205463ffffffff918216600160301b9091049091161115611d50565b60015b151560c08301526080840151611d67576001611d98565b81515160a08301515160020b60009081526020899052604090205463ffffffff918216600160301b90910490911611155b151560e08301525b8360800151611db3578360200151611db9565b83604001515b60020b846060015160020b14611e6157815160006080909101819052606085015160020b81526020899052604090206001015461010083018051600160801b9092046001600160801b031691611e10908390613301565b6001600160801b039081169091526060860151600290810b600090815260208c905260409020015461012085018051919092169250611e50908390613301565b6001600160801b0316905250611f5e565b606084018051600290810b600090815260208b90526040808220830154935190920b81522060010154670de0b6b3a764000091611ebc9167ffffffffffffffff600160801b9283900416916001600160801b03910416613632565b611ec69190613661565b8261010001818151611ed89190613301565b6001600160801b03908116909152606086018051600290810b600090815260208d905260408082208301549351830b825290200154670de0b6b3a76400009350611f3592600160c01b90920467ffffffffffffffff169116613632565b611f3f9190613661565b8261012001818151611f519190613301565b6001600160801b03169052505b8560a0015160020b846060015160020b036123215760a08401516001600160801b0316156121415783608001516120275760a084015160408084015160018801549151630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9363580680d893611fe19391926001600160a01b03909116906004016132a8565b602060405180830381865af4158015611ffe573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061202291906132d2565b6120bb565b60a084015160018601546040808501519051630e8e499360e21b815273__$357eccfa53a4e88c122661903e0e603301$__93633a39264c9361207a9391926001600160a01b0390911691906004016132a8565b602060405180830381865af4158015612097573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906120bb91906132d2565b825160600180516120cd908390613301565b6001600160801b0390811690915260a0860151875490821691160390506120fc5784546001600160801b031685555b60a08401518554869060009061211c9084906001600160801b031661332c565b92506101000a8154816001600160801b0302191690836001600160801b031602179055505b6080808301516001600160a01b0316604084015284015161221b57815160208101516001870154604085015160a09093015173__$357eccfa53a4e88c122661903e0e603301$__93633a39264c93926001600160a01b03908116929181169116116121b05785608001516121b7565b855160a001515b6040518463ffffffff1660e01b81526004016121d5939291906132a8565b602060405180830381865af41580156121f2573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061221691906132d2565b6122e6565b73__$357eccfa53a4e88c122661903e0e603301$__63580680d883600001516020015184604001516001600160a01b0316856000015160a001516001600160a01b03161061226d578460800151612274565b845160a001515b60018901546040516001600160e01b031960e086901b1681526122a59392916001600160a01b0316906004016132a8565b602060405180830381865af41580156122c2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906122e691906132d2565b825160400180516122f8908390613301565b6001600160801b0390811690915286548451600160801b9091049091166080909101525061232c565b815160006080909101525b505b60a08301516001600160801b03161561247d5782608001516123d65760a083015160408083015160608401519151630b00d01b60e31b815273__$357eccfa53a4e88c122661903e0e603301$__9363580680d8936123909391926004016132a8565b602060405180830381865af41580156123ad573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906123d191906132d2565b61245e565b73__$357eccfa53a4e88c122661903e0e603301$__633a39264c8460a00151836020015184604001516040518463ffffffff1660e01b815260040161241d939291906132a8565b602060405180830381865af415801561243a573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061245e91906132d2565b81516060018051612470908390613301565b6001600160801b03169052505b6101208101516001600160801b03161561254a5761012081015181516020015160405163554d048960e11b81526001600160801b03928316600482015291166024820152600160601b604482015273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015612507573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061252b91906132d2565b8151606001805161253d908390613301565b6001600160801b03169052505b6101008101516001600160801b0316156126225761010081015181516020015160405163554d048960e11b81526001600160801b03928316600482015291166024820152600160601b604482015273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af41580156125d4573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906125f891906132d2565b612603906001613687565b8151604001805161261590839061332c565b6001600160801b03169052505b60208501516126389061ffff16620f424061369f565b62ffffff16816000015160400151620f42406126549190613632565b61265e9190613661565b81516001600160801b0390911660409091015260a08501516060840151600290810b91900b146126925780604001516126a1565b60018401546001600160a01b03165b81516001600160a01b0391821660a090910152608082015160018601549082169116036126e157604081015181516001600160a01b0390911660a0909101525b604081015160018501546001600160a01b0391821691160361271657608081015181516001600160a01b0390911660a0909101525b60a08301516001600160801b03161561285357826080015161273c578260200151612742565b82604001515b60020b836060015160020b1461277557826080015161276957600060c08201819052612773565b600060e082018190525b505b73__$dc25dd3a5fe6a540f35c01c335c2ccfd23$__63dd3fac9288888887608001516127a55787606001516127ab565b87602001515b88608001516127be5788604001516127c4565b88606001515b8960a001518a608001518960c001518a60e001516040518a63ffffffff1660e01b81526004016127fc99989796959493929190613241565b60006040518083038186803b15801561281457600080fd5b505af4158015612828573d6000803e3d6000fd5b505050508260a001518160000151602001818151612846919061332c565b6001600160801b03169052505b826080015161287357826020015160020b836060015160020b1415612886565b826040015160020b836060015160020b14155b156128f75782516001600160a01b031660009081526020898152604080832082870151600290810b855290835281842082880151820b8552909252822080546001600160a01b03199081168255600182019390935590810180546001600160801b0319169055600301805490911690555b82608001516129c857805183516001600160a01b03908116600090815260208b815260408083206060808a0151600290810b8652918452828520838b0151830b8652845293829020865181549488015163ffffffff9091166001600160a01b031995861617600160201b6001600160801b03928316021782559287015194870151948316600160801b95841695909502949094176001850155608086015190840180546001600160801b0319169190921617905560a090930151600382018054909416921691909117909155612a8d565b805183516001600160a01b03908116600090815260208b8152604080832082890151600290810b85529083528184206060808b0151830b865290845293829020865181549488015163ffffffff9091166001600160a01b031995861617600160201b6001600160801b03928316021782559287015194870151948316600160801b95841695909502949094176001850155608086015190840180546001600160801b0319169190921617905560a0909301516003820180549094169216919091179091555b50849150505b9695505050505050565b604080516101a081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e08101829052610100810182905261012081018290526101408101829052610160810182905261018081019190915290565b6040516101a0810167ffffffffffffffff81118282101715612b3b57634e487b7160e01b600052604160045260246000fd5b60405290565b60405160a0810167ffffffffffffffff81118282101715612b3b57634e487b7160e01b600052604160045260246000fd5b60405160e0810167ffffffffffffffff81118282101715612b3b57634e487b7160e01b600052604160045260246000fd5b60405160c0810167ffffffffffffffff81118282101715612b3b57634e487b7160e01b600052604160045260246000fd5b60ff81168114612be357600080fd5b50565b8035612bf181612bd4565b919050565b61ffff81168114612be357600080fd5b8035612bf181612bf6565b8060010b8114612be357600080fd5b8035612bf181612c11565b8060020b8114612be357600080fd5b8035612bf181612c2b565b63ffffffff81168114612be357600080fd5b8035612bf181612c45565b6001600160801b0381168114612be357600080fd5b8035612bf181612c62565b6001600160a01b0381168114612be357600080fd5b8035612bf181612c82565b60006101a08284031215612cb557600080fd5b612cbd612b09565b9050612cc882612be6565b8152612cd660208301612c06565b6020820152612ce760408301612c20565b6040820152612cf860608301612c06565b6060820152612d0960808301612c06565b6080820152612d1a60a08301612c3a565b60a0820152612d2b60c08301612c57565b60c0820152612d3c60e08301612c57565b60e0820152610100612d4f818401612c57565b90820152610120612d61838201612c57565b90820152610140612d73838201612c77565b90820152610160612d85838201612c97565b90820152610180612d97838201612c97565b9082015292915050565b80358015158114612bf157600080fd5b60008060008060008587036102a0811215612dcb57600080fd5b863595506020870135945060408701359350612dea8860608901612ca2565b925060a06101ff1982011215612dff57600080fd5b50612e08612b41565b610200870135612e1781612c82565b8152610220870135612e2881612c2b565b6020820152610240870135612e3c81612c2b565b6040820152612e4e6102608801612da1565b6060820152610280870135612e6281612c62565b6080820152949793965091945092919050565b805160ff1682526020810151612e91602084018261ffff169052565b506040810151612ea6604084018260010b9052565b506060810151612ebc606084018261ffff169052565b506080810151612ed2608084018261ffff169052565b5060a0810151612ee760a084018260020b9052565b5060c0810151612eff60c084018263ffffffff169052565b5060e0810151612f1760e084018263ffffffff169052565b506101008181015163ffffffff908116918401919091526101208083015190911690830152610140808201516001600160801b031690830152610160808201516001600160a01b03908116918401919091526101809182015116910152565b6001600160801b03831681526101c08101612f946020830184612e75565b9392505050565b60008060008060008587036102e0811215612fb557600080fd5b863595506020870135945060408701359350612fd48860608901612ca2565b925060e06101ff1982011215612fe957600080fd5b50612ff2612b72565b61020087013561300181612c82565b815261022087013561301281612c2b565b602082015261024087013561302681612c2b565b604082015261026087013561303a81612c2b565b606082015261304c6102808801612c3a565b608082015261305e6102a08801612da1565b60a08201526130706102c08801612c77565b60c0820152809150509295509295909350565b6000610260828403121561309657600080fd5b61309e612b72565b82356130a981612c2b565b815260208301356130b981612c2b565b602082015260408301356130cc81612c2b565b604082015260608301356130df81612c2b565b60608201526130f060808401612da1565b608082015260a083013561310381612c62565b60a08201526131158460c08501612ca2565b60c08201529392505050565b6000806000806000808688036102e081121561313c57600080fd5b87359650602088013595506040880135945061315b8960608a01612ca2565b9350610200880135925060c061021f198201121561317857600080fd5b50613181612ba3565b61022088013561319081612c82565b81526102408801356131a181612c2b565b60208201526102608801356131b581612c2b565b60408201526102808801356131c981612c2b565b60608201526131db6102a08901612da1565b60808201526102c08801356131ef81612c62565b8060a083015250809150509295509295509295565b6101a081016132138284612e75565b92915050565b8051612bf181612c82565b60006020828403121561323657600080fd5b8151612f9481612c82565b898152602081018990526102a0810161325d604083018a612e75565b600297880b6101e08301529590960b6102008701526001600160801b039390931661022086015290151561024085015215156102608401521515610280909201919091529392505050565b6001600160801b039390931683526001600160a01b03918216602084015216604082015260600190565b6000602082840312156132e457600080fd5b5051919050565b634e487b7160e01b600052601160045260246000fd5b60006001600160801b03808316818516808303821115613323576133236132eb565b01949350505050565b60006001600160801b038381169083168181101561334c5761334c6132eb565b039392505050565b898152602081018990526102a08101613370604083018a612e75565b8760020b6101e08301528660020b6102008301528560020b6102208301528460020b6102408301526001600160801b0384166102608301528215156102808301529a9950505050505050505050565b8051612bf181612bd4565b8051612bf181612bf6565b8051612bf181612c11565b8051612bf181612c2b565b8051612bf181612c45565b8051612bf181612c62565b60006101a0828403121561341457600080fd5b61341c612b09565b613425836133bf565b8152613433602084016133ca565b6020820152613444604084016133d5565b6040820152613455606084016133ca565b6060820152613466608084016133ca565b608082015261347760a084016133e0565b60a082015261348860c084016133eb565b60c082015261349960e084016133eb565b60e08201526101006134ac8185016133eb565b908201526101206134be8482016133eb565b908201526101406134d08482016133f6565b908201526101606134e2848201613219565b908201526101806134f4848201613219565b908201529392505050565b634e487b7160e01b600052601260045260246000fd5b60008260020b80613528576135286134ff565b808360020b0791505092915050565b60008160020b627fffff198103613550576135506132eb565b60000392915050565b60008160020b8360020b6000811281627fffff1901831281151615613580576135806132eb565b81627fffff018313811615613597576135976132eb565b5090039392505050565b60008160020b8360020b6000821282627fffff038213811516156135c7576135c76132eb565b82627fffff190382128116156135df576135df6132eb565b50019392505050565b6000816000190483118215151615613602576136026132eb565b500290565b600082613616576136166134ff565b500490565b60008282101561362d5761362d6132eb565b500390565b60006001600160801b0380831681851681830481118215151615613658576136586132eb565b02949350505050565b60006001600160801b038084168061367b5761367b6134ff565b92169190910492915050565b6000821982111561369a5761369a6132eb565b500190565b600062ffffff8381169083168181101561334c5761334c6132eb56fea26469706673582212200e55ee85131739c086486ce7df3527c1ef2c88629c8f249daef365d9b2558b6764736f6c634300080d0033";

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
