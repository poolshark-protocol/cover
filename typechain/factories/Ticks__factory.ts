/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Ticks, TicksInterface } from "../Ticks";

const _abi = [
  {
    inputs: [],
    name: "NoLiquidityToRollover",
    type: "error",
  },
  {
    inputs: [],
    name: "NotImplementedYet",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickLowerOld",
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
    name: "WrongTickUpperOld",
    type: "error",
  },
  {
    inputs: [],
    name: "WrongTickUpperRange",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "tickSpacing",
        type: "int24",
      },
    ],
    name: "getMaxLiquidity",
    outputs: [
      {
        internalType: "uint128",
        name: "",
        type: "uint128",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x613d7861003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe730000000000000000000000000000000000000000301460806040526004361061006c5760003560e01c806324cfd9df14610071578063344a4e7f146100a15780637efa8fae146100c35780638507ea62146100e35780638c15c5f514610112578063baae218714610132575b600080fd5b61008461007f3660046134cf565b610164565b6040516001600160801b0390911681526020015b60405180910390f35b8180156100ad57600080fd5b506100c16100bc366004613518565b6101a4565b005b8180156100cf57600080fd5b506100c16100de3660046135b8565b610523565b8180156100ef57600080fd5b506101036100fe366004613719565b61161e565b604051610098939291906137e2565b81801561011e57600080fd5b506100c161012d366004613810565b6122a4565b61014561014036600461384f565b612610565b60408051938452600292830b6020850152910b90820152606001610098565b60006101718260026138cb565b61017e620d89e7196138f6565b610188919061392e565b61019e9062ffffff166001600160801b03613950565b92915050565b60008083156102a057841561025257600288900b600090815260208b90526040812080548892906101d9908490600f0b61396a565b82546101009290920a6001600160801b0381810219909316918316021790915560028a900b600090815260208d90526040902080548993509091601091610229918591600160801b9004166139b9565b92506101000a8154816001600160801b0302191690836001600160801b031602179055506102a0565b600288900b600090815260208b9052604081208054889290610278908490600f0b6139e1565b92506101000a8154816001600160801b030219169083600f0b6001600160801b031602179055505b801561038e57600287810b600090815260208b9052604090205480820b916301000000909104810b908a900b821415806102d8575083155b1561033157600282810b600090815260208d90526040808220805465ffffff0000001916630100000062ffffff87811691909102919091179091559284900b82529020805462ffffff191691841691909117905561038b565b60028a810b600090815260208d905260408082205480840b8352818320805465ffffff0000001916630100000062ffffff88811691909102919091179091559385900b83529120805462ffffff1916929091169190911790555b50505b82156104875784156103ec57600287900b600090815260208b90526040812080548892906103c0908490600f0b6139e1565b92506101000a8154816001600160801b030219169083600f0b6001600160801b03160217905550610487565b600287900b600090815260208b9052604081208054889290610412908490600f0b61396a565b82546101009290920a6001600160801b03818102199093169183160217909155600289900b600090815260208d90526040902080548993509091601091610462918591600160801b9004166139b9565b92506101000a8154816001600160801b0302191690836001600160801b031602179055505b6104cf6040518060400160405280601881526020017f72656d6f766564206c6f776572206c69717569646974793a0000000000000000815250876001600160801b0316612686565b6105176040518060400160405280601881526020017f72656d6f766564207570706572206c69717569646974793a0000000000000000815250876001600160801b0316612686565b50505050505050505050565b8260020b8560020b12158061053e57508360020b8660020b12155b1561055c5760405163338d790760e01b815260040160405180910390fd5b600285900b620d89e7191315610585576040516345bde0e360e11b815260040160405180910390fd5b610592620d89e7196138f6565b60020b8360020b13156105b85760405163093cbe4760e21b815260040160405180910390fd5b600285900b600090815260208b90526040902054600f0b1515806105fe5750600285900b600090815260208b90526040902054600160801b90046001600160801b031615155b8061061f5750600285810b600090815260208c9052604090200154600f0b15155b1561079d5761064f6040518060400160405280600a815260200169696e73657274206c697160b01b815250612640565b80156106f457600285900b600090815260208b905260408120805484929061067b908490600f0b6139e1565b82546101009290920a6001600160801b03818102199093169183160217909155600287900b600090815260208d905260409020805485935090916010916106cb918591600160801b900416613a31565b92506101000a8154816001600160801b0302191690836001600160801b03160217905550610742565b600285900b600090815260208b905260408120805484929061071a908490600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b031602179055505b600285900b600090815260208b905260408120600101546001600160e81b0316900361079857600285900b600090815260208b90526040902060010180546001600160e81b0319166001600160e81b0389161790555b610b39565b8015610974576040518060e00160405280836107b890613a5c565b600f0b8152602001836001600160801b03168152602001886001600160e81b031681526020016000600f0b81526020016000600f0b815260200160006001600160401b0316815260200160006001600160401b03168152508a60008760020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160e81b0302191690836001600160e81b0316021790555060608201518160020160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060808201518160020160106101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060a08201518160030160006101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160030160086101000a8154816001600160401b0302191690836001600160401b03160217905550905050610b39565b6040518060e0016040528083600f0b815260200160006001600160801b03168152602001886001600160e81b031681526020016000600f0b81526020016000600f0b815260200160006001600160401b0316815260200160006001600160401b03168152508a60008760020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160e81b0302191690836001600160e81b0316021790555060608201518160020160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060808201518160020160106101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060a08201518160030160006101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160030160086101000a8154816001600160401b0302191690836001600160401b031602179055509050505b610b646040518060400160405280600a8152602001696c6f776572207469636b60b01b815250612640565b600285810b600090815260208b90526040902054610b8b916301000000909104900b6126cf565b600285810b600090815260208b90526040902054610ba9910b6126cf565b600285810b600090815260208b9052604090205463010000008104820b910b148015610bdd5750600285900b620d89e71914155b15610d8857610c0d6040518060400160405280600a8152602001696c6f776572207469636b60b01b815250612640565b600286810b600090815260208b9052604090205463010000009004810b9084900b811315610c3c575082610c61565b600281900b600090815260208b905260409020805462ffffff191662ffffff88161790555b8560020b8760020b121580610c7c57508060020b8660020b12155b15610d0a57610cac6040518060400160405280600a8152602001697469636b20636865636b60b01b815250612640565b600287810b600090815260208c90526040902054610cd3916301000000909104900b6126cf565b600287810b600090815260208c90526040902054610cf1910b6126cf565b60405163044f7fb160e51b815260040160405180910390fd5b610d168160020b6126cf565b604080518082018252600289810b80835293810b6020808401918252918a900b6000908152918e905283822092518354915162ffffff91821665ffffffffffff1990931692909217630100000092821683021790935593815291909120805465ffffff00000019169188169092021790555b610db36040518060400160405280600a8152602001696c6f776572207469636b60b01b815250612640565b600285810b600090815260208b90526040902054610dda916301000000909104900b6126cf565b600285810b600090815260208b90526040902054610df8910b6126cf565b610e236040518060400160405280600a8152602001697570706572207469636b60b01b815250612640565b600283810b600090815260208b90526040902054610e41910b6126cf565b600283810b600090815260208b90526040902054610e68916301000000909104900b6126cf565b600283900b600090815260208b90526040902054600f0b151580610eae5750600283900b600090815260208b90526040902054600160801b90046001600160801b031615155b80610ecf5750600285810b600090815260208c9052604090200154600f0b15155b15611022578015610f2c57600283900b600090815260208b9052604081208054849290610f00908490600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b03160217905550610fc7565b600283900b600090815260208b9052604081208054849290610f52908490600f0b6139e1565b82546101009290920a6001600160801b03818102199093169183160217909155600285900b600090815260208d90526040902080548593509091601091610fa2918591600160801b900416613a31565b92506101000a8154816001600160801b0302191690836001600160801b031602179055505b600283900b600090815260208b905260408120600101546001600160e81b0316900361101d57600283900b600090815260208b90526040902060010180546001600160e81b0319166001600160e81b0389161790555b6113f3565b80156111f1576040518060e0016040528083600f0b815260200160006001600160801b03168152602001886001600160e81b031681526020016000600f0b81526020016000600f0b815260200160006001600160401b0316815260200160006001600160401b03168152508a60008560020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160e81b0302191690836001600160e81b0316021790555060608201518160020160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060808201518160020160106101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060a08201518160030160006101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160030160086101000a8154816001600160401b0302191690836001600160401b031602179055509050506113f3565b611226604051806040016040528060148152602001731d5c1c195c88191bd95cc81b9bdd08195e1a5cdd60621b815250612640565b6040518060e001604052808361123b90613a5c565b600f0b8152602001836001600160801b03168152602001886001600160e81b031681526020016000600f0b81526020016000600f0b815260200160006001600160401b0316815260200160006001600160401b03168152508a60008560020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160e81b0302191690836001600160e81b0316021790555060608201518160020160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060808201518160020160106101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060a08201518160030160006101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160030160086101000a8154816001600160401b0302191690836001600160401b031602179055509050505b61141e6040518060400160405280600a8152602001697570706572207469636b60b01b815250612640565b600283810b600090815260208b9052604090205461143c910b6126cf565b600283810b600090815260208b90526040902054611463916301000000909104900b6126cf565b600283810b600090815260208b9052604090205463010000008104820b910b1480156114a15750611497620d89e7196138f6565b60020b8360020b14155b1561051757600284810b600090815260208b90526040902054900b6114c5816126cf565b8060020b8660020b13156114d65750845b611500604051806040016040528060098152602001687570706572206e657760b81b815250612640565b61150c8160020b6126cf565b6115188560020b6126cf565b6115248460020b6126cf565b6115308960020b6126cf565b600285810b600090815260208c9052604090205463010000008104820b910b148061156157508360020b8560020b13155b8061157257508060020b8460020b13155b15611590576040516329f7012160e21b815260040160405180910390fd5b604080518082018252600292830b80825296830b60208083018281529488900b60009081529d9052828d2091518254945162ffffff91821665ffffffffffff19909616959095176301000000958216860217909255968c52818c20805465ffffff000000191691909616928302179094559389525050909520805462ffffff19169095179094555050505050565b6040805160a0810182526000808252602082018190529181018290526060810182905260808101919091526040805160a0810182526000808252602082018190529181018290526060810182905260808101919091526000611697604051806060016040528060218152602001613cfd60219139612640565b6116a2846002613a79565b6116ac9087613b06565b60020b8460026116bc9190613a79565b6116c69087613b06565b60020b036116fc576116ef604051806060016040528060258152602001613d1e60259139612640565b5086915085905084612296565b60408051610140810182528951600290810b600090815260208d815284822054630100000090819004840b85528c51840b828601528d51840b858701528c51840b8352908e90529381205493909304810b6060830152608082019089810b9089900b136117725761176d8789613b40565b611774565b885b60020b81526020018860020b8860020b1361178f5788611799565b6117998789613b7e565b60020b81526020016000600f0b81526020016000600f0b81526020016000600f0b81526020016000600f0b81525090506117d9816000015160020b6126cf565b6117e9896020015160020b6126cf565b6020808a0151600290810b6000908152918c9052604090912054611816916301000000909104900b6126cf565b886020015160020b816000015160020b146118b3576118468c8b836040015184600001518d606001516000612714565b600290810b845290810b60408401526001600160801b0390911660608b01528151611871910b6126cf565b611881896020015160020b6126cf565b6020808a0151600290810b6000908152918c90526040909120546118ae916301000000909104900b6126cf565b611816565b876020015160020b816020015160020b1461190b576118e38b8b836060015184602001518c606001516001612714565b600290810b60208501520b6060838101919091526001600160801b03909116908901526118b3565b806080015160020b816040015160020b12611a0b5760608901516001600160801b0316156119805761196e816000015182604001518b604001516001600160a01b03168c606001516001600160801b03168560c0015186610100015160016127b5565b600f90810b6101008401520b60c08201525b6119b16040518060400160405280601081526020016f706f6f6c3020616363756d756c61746560801b815250612640565b80516119bf9060020b6126cf565b6119cf816040015160020b6126cf565b6119f98c826000015183604001518c606001518d608001518660c001518761010001516001612cc4565b600f90810b6101008401520b60c08201525b611a1b816040015160020b6126cf565b611a2b816080015160020b6126cf565b806080015160020b816040015160020b1315611a7c57611a5c8c8b836000015184604001518d606001516001612714565b600290810b60408501520b82526001600160801b031660608a015261190b565b8660020b8660020b1315611b0b57600287900b600090815260208d9052604090205460608a0151611abd91600160801b90046001600160801b0316906139b9565b600288900b600090815260208e9052604081208054909190611ae3908490600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b031602179055505b611b298c82608001518360c001518461010001518d606001516131fd565b8660020b8660020b1215611b6e57611b528c8b836000015184604001518d606001516001612714565b600290810b60408501520b82526001600160801b031660608a01525b8060a0015160020b816060015160020b13611c705760608801516001600160801b031615611be357611bd1816020015182606001518a604001516001600160a01b03168b606001516001600160801b03168560e0015186610120015160006127b5565b600f90810b6101208401520b60e08201525b611c146040518060400160405280601081526020016f706f6f6c3120616363756d756c61746560801b815250612640565b611c24816020015160020b6126cf565b611c34816060015160020b6126cf565b611c5e8b826020015183606001518b606001518c608001518660e001518761012001516001612cc4565b600f90810b6101208401520b60e08201525b611c80816060015160020b6126cf565b611c908160a0015160020b6126cf565b8060a0015160020b816060015160020b1215611ceb57611cc18b8b836020015184606001518c606001516000612714565b600290810b60608581019190915291900b60208401526001600160801b0390911690890152611b6e565b8660020b8660020b1215611d7a57600287900b600090815260208c905260409020546060890151611d2c91600160801b90046001600160801b0316906139b9565b600288900b600090815260208d9052604081208054909190611d52908490600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b031602179055505b611d988b8260a001518360e001518461012001518c606001516131fd565b8660020b8660020b1315611de757611dc18b8b836020015184606001518c606001516000612714565b600290810b60608581019190915291900b60208401526001600160801b03909116908901525b8660020b8660020b1315611ff7578560020b816060015160020b14611f8f57611e356040518060400160405280600e81526020016d074776170206d6f76696e672075760941b815250612640565b611e458160a0015160020b6126cf565b602080820151600290810b6000908152918c9052604090912054611e72916301000000909104900b6126cf565b611e82816060015160020b6126cf565b6040518060400160405280826020015160020b8152602001826060015160020b8152508a60008860020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff160217905550905050858a6000836060015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff160217905550858a6000836020015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff1602179055505b60006060808b01829052890180516001600160801b03169052600287810b825260208c815260409092205463010000009004810b828c0190815283830151820b928b01929092529051611fe2910b6126cf565b611ff2886020015160020b6126cf565b612193565b8660020b8660020b1215612193578560020b816040015160020b14612123576040518060400160405280826040015160020b8152602001826000015160020b8152508a60008860020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff160217905550905050858a6000836000015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff160217905550858a6000836040015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff1602179055505b6121546040518060400160405280601081526020016f3a3bb0b81036b7bb34b733903237bbb760811b815250612640565b6060808a0180516001600160801b0316905260009089018190528151600290810b6020808d019190915288820b83528c8152604090922054900b908901525b600286810b600081815260208d815260408083205463010000008104860b8f5292849052908e9052920b8a52905163986cfba360e01b8152600481019190915273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af415801561220f573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906122339190613bbc565b6001600160a01b03166040808b01829052898101919091528051808201909152601f81527f2d2d20454e4420414343554d554c415445204c41535420424c4f434b202d2d006020820152959650869561228b90612640565b888888935093509350505b985098509895505050505050565b600281900b620d89e719148015906122ce57506122c4620d89e7196138f6565b60020b8160020b14155b156123ed576040518060400160405280620d89e71960020b8152602001620d89e7196122f9906138f6565b600290810b90915282900b600081815260208781526040808320855181549684015162ffffff91821665ffffffffffff1998891617630100000091831682021790925582518084018452620d89e7198082528186018881528188528d87529685902091518254975190841697909916969096179790911690910295909517909455835180850190945291835290820190612392906138f6565b60020b90528460006123a7620d89e7196138f6565b60020b815260208082019290925260400160002082518154939092015162ffffff90811663010000000265ffffffffffff199094169216919091179190911790556124f2565b600281900b620d89e7191480612414575061240b620d89e7196138f6565b60020b8160020b145b156124f2576040518060400160405280620d89e71960020b8152602001620d89e71961243f906138f6565b60020b9052620d89e71960008181526020878152604091829020845181549583015162ffffff90811663010000000265ffffffffffff199097169116179490941790935580518082019091528181529182019061249b906138f6565b60020b90528460006124b0620d89e7196138f6565b60020b815260208082019290925260400160002082518154939092015162ffffff90811663010000000265ffffffffffff199094169216919091179190911790555b825462ffffff1990811662ffffff831617845582541662f2761817825561251c620d89e7196138f6565b835462ffffff9190911663010000000265ffffff00000019918216178455825465f27618000000911617825560405163986cfba360e01b815273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba39061258890849060040160029190910b815260200190565b602060405180830381865af41580156125a5573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906125c99190613bbc565b83546001600160a01b0391821666010000000000009081026601000000000000600160d01b0319928316179586905584549581900490921690910293169290921790555050565b6000806000612623898989898989612714565b6001600160801b0390921694509250905096509650969350505050565b612683816040516024016126549190613c26565b60408051601f198184030181529190526020810180516001600160e01b031663104c13eb60e21b179052613452565b50565b6126cb828260405160240161269c929190613c39565b60408051601f198184030181529190526020810180516001600160e01b0316632d839cb360e21b179052613452565b5050565b612683816040516024016126e591815260200190565b60408051601f198184030181529190526020810180516001600160e01b0316632d5b6cb960e01b179052613452565b600283900b600090815260208790526040812054939450849381908190600f0b8181131561274d576127468187613a31565b9550612763565b61275681613a5c565b61276090876139b9565b95505b841561278657600296870b600090815260208a9052604090205490960b956127a6565b600296870b600090815260208a905260409020546301000000900490960b955b50939895975093955050505050565b600080856000036127ca575083905082612cb8565b60405163986cfba360e01b815260028a900b600482015260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af4158015612820573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906128449190613bbc565b90508361285d57806001600160a01b031688111561286b565b806001600160a01b03168810155b1561287c5785859250925050612cb8565b60405163986cfba360e01b815260028a900b600482015260009073__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156128d2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906128f69190613bbc565b90508461290e57806001600160a01b0316891161291b565b806001600160a01b031689105b1561292d57806001600160a01b031698505b6000808615612a6257604051639026147360e01b8152600481018b9052602481018c90526001600160a01b03851660448201526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af41580156129a3573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906129c79190613c5b565b604051630724718960e41b8152600481018c9052602481018d90526001600160a01b03861660448201526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af4158015612a37573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612a5b9190613c5b565b9150612b8a565b604051630724718960e41b8152600481018b90526001600160a01b0385166024820152604481018c90526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af4158015612acf573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612af39190613c5b565b604051639026147360e01b8152600481018c90526001600160a01b0386166024820152604481018d90526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af4158015612b63573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612b879190613c5b565b91505b60405163554d048960e11b815260048101839052600160601b6024820152604481018b905273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015612beb573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612c0f9190613c5b565b612c19908a6139e1565b60405163554d048960e11b815260048101839052600160601b6024820152604481018c905290995073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015612c7d573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612ca19190613c5b565b612cab908961396a565b9750888895509550505050505b97509795505050505050565b600080612d056040518060400160405280601b81526020017f6665652067726f77746820616363756d756c61746520636865636b0000000000815250612640565b600289900b600090815260208b90526040902060010154612d2e906001600160e81b0316613473565b600288900b600090815260208b90526040902060010154612d57906001600160e81b0316613473565b600288900b600090815260208b90526040902060010180546001600160e81b0319166001600160e81b0388161790558215612da157600289900b600090815260208b905260408120555b600289900b600090815260208b905260409020600301546001600160401b031615612fac57600289810b600090815260208c905260408120918201546003909201549091670de0b6b3a764000091612e0891600f0b906001600160401b031660070b613c74565b612e129190613cc7565b60028b810b600090815260208e90526040812090910180549293508392909190612e40908490600f0b6139e1565b82546001600160801b039182166101009390930a92830291909202199091161790555060028a900b600090815260208c905260409020600301805467ffffffffffffffff19169055612e92818761396a565b60028b900b600090815260208d90526040902060030154909650600160401b90046001600160401b031615612faa5760028a810b600090815260208d905260408120918201546003909201549091670de0b6b3a764000091612f1191600160801b9004600f0b90600160401b90046001600160401b031660070b613c74565b612f1b9190613cc7565b60028c810b600090815260208f905260409020018054600f92830b93508392601091612f51918591600160801b9004900b6139e1565b82546001600160801b039182166101009390930a92830291909202199091161790555060028b900b600090815260208d905260409020600301805467ffffffffffffffff60401b19169055612fa6818761396a565b9550505b505b6001600160801b038716156131ed57600288900b600090815260208b905260409020546001600160801b03600160801b9091048116908816811461313e57600289810b600090815260208d9052604081209091018054889290613013908490600f0b61396a565b82546001600160801b039182166101009390930a928302919092021990911617905550600289810b600090815260208d905260409020018054869190601090613067908490600160801b9004600f0b61396a565b82546001600160801b039182166101009390930a928302919092021990911617905550600289900b600090815260208c905260408120546130ac908390600f0b61396a565b9050600081600f0b13156131385760006130c6838b6139b9565b6130d883670de0b6b3a7640000613c74565b6130e29190613cc7565b9050670de0b6b3a76400006130f7828261396a565b6131019089613c74565b61310b9190613cc7565b9650670de0b6b3a7640000613120828261396a565b61312a908a613c74565b6131349190613cc7565b9750505b506131eb565b600289810b600090815260208d9052604081209091018054889290613167908490600f0b61396a565b82546001600160801b039182166101009390930a928302919092021990911617905550600289810b600090815260208d9052604090200180548691906010906131bb908490600160801b9004600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060009550600094505b505b5092989197509095505050505050565b6001600160801b0381161561344b57600284810b6000908152602087905260408120918201546003909201549091670de0b6b3a76400009161324e91600f0b906001600160401b031660070b613c74565b6132589190613cc7565b600286810b6000908152602089905260409020015490915061327e908590600f0b61396a565b613288828661396a565b61329a90670de0b6b3a7640000613c74565b6132a49190613cc7565b600286810b600090815260208990526040812060038101805467ffffffffffffffff19166001600160401b039590951694909417909355910180548692906132f0908490600f0b61396a565b82546001600160801b039182166101009390930a928302919092021990911617905550600285810b6000908152602088905260408120918201546003909201549091670de0b6b3a76400009161336491600160801b9004600f0b906001600160401b03600160401b9091041660070b613c74565b61336e9190613cc7565b600287810b600090815260208a905260409020015490915061339b908590600160801b9004600f0b61396a565b6133a5828661396a565b6133b790670de0b6b3a7640000613c74565b6133c19190613cc7565b600287810b600090815260208a9052604090206003810180546001600160401b0394909416600160401b0267ffffffffffffffff60401b1990941693909317909255018054859190601090613421908490600160801b9004600f0b61396a565b92506101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555050505b5050505050565b80516a636f6e736f6c652e6c6f67602083016000808483855afa5050505050565b6126838160405160240161348991815260200190565b60408051601f198184030181529190526020810180516001600160e01b031663f82c50f160e01b179052613452565b8035600281900b81146134ca57600080fd5b919050565b6000602082840312156134e157600080fd5b6134ea826134b8565b9392505050565b80356001600160801b03811681146134ca57600080fd5b803580151581146134ca57600080fd5b600080600080600080600080610100898b03121561353557600080fd5b883597506020890135965061354c60408a016134b8565b955061355a60608a016134b8565b945061356860808a016134f1565b935061357660a08a01613508565b925061358460c08a01613508565b915061359260e08a01613508565b90509295985092959890939650565b80356001600160e81b03811681146134ca57600080fd5b6000806000806000806000806000806101408b8d0312156135d857600080fd5b8a35995060208b013598506135ef60408c016134b8565b97506135fd60608c016135a1565b965061360b60808c016134b8565b955061361960a08c016134b8565b945061362760c08c016134b8565b935061363560e08c016134b8565b92506136446101008c016134f1565b91506136536101208c01613508565b90509295989b9194979a5092959850565b6001600160a01b038116811461268357600080fd5b600060a0828403121561368b57600080fd5b60405160a081018181106001600160401b03821117156136bb57634e487b7160e01b600052604160045260246000fd5b6040529050806136ca836134b8565b81526136d8602084016134b8565b602082015260408301356136eb81613664565b60408201526136fc606084016134f1565b606082015261370d608084016135a1565b60808201525092915050565b600080600080600080600080610200898b03121561373657600080fd5b8835975060208901359650604089013595506137558a60608b01613679565b94506137658a6101008b01613679565b93506137746101a08a016134b8565b92506137836101c08a016134b8565b91506135926101e08a016134b8565b8051600290810b835260208083015190910b908301526040808201516001600160a01b0316908301526060808201516001600160801b0316908301526080908101516001600160e81b0316910152565b61016081016137f18286613792565b6137fe60a0830185613792565b8260020b610140830152949350505050565b6000806000806080858703121561382657600080fd5b843593506020850135925060408501359150613844606086016134b8565b905092959194509250565b60008060008060008060c0878903121561386857600080fd5b863595506020870135945061387f604088016134b8565b935061388d606088016134b8565b925061389b608088016134f1565b91506138a960a08801613508565b90509295509295509295565b634e487b7160e01b600052601160045260246000fd5b600062ffffff808316818516818304811182151516156138ed576138ed6138b5565b02949350505050565b60008160020b627fffff19810361390f5761390f6138b5565b60000392915050565b634e487b7160e01b600052601260045260246000fd5b600062ffffff8084168061394457613944613918565b92169190910492915050565b60006001600160801b038084168061394457613944613918565b600081600f0b83600f0b600082128260016001607f1b0303821381151615613994576139946138b5565b8260016001607f1b03190382128116156139b0576139b06138b5565b50019392505050565b60006001600160801b03838116908316818110156139d9576139d96138b5565b039392505050565b600081600f0b83600f0b600081128160016001607f1b031901831281151615613a0c57613a0c6138b5565b8160016001607f1b03018313811615613a2757613a276138b5565b5090039392505050565b60006001600160801b03808316818516808303821115613a5357613a536138b5565b01949350505050565b600081600f0b60016001607f1b0319810361390f5761390f6138b5565b60008160020b8360020b627fffff600082136000841383830485118282161615613aa557613aa56138b5565b627fffff196000851282811687830587121615613ac457613ac46138b5565b60008712925085820587128484161615613ae057613ae06138b5565b85850587128184161615613af657613af66138b5565b5050509290910295945050505050565b60008160020b8360020b80613b1d57613b1d613918565b627fffff19821460001982141615613b3757613b376138b5565b90059392505050565b60008160020b8360020b6000821282627fffff03821381151615613b6657613b666138b5565b82627fffff190382128116156139b0576139b06138b5565b60008160020b8360020b6000811281627fffff1901831281151615613ba557613ba56138b5565b81627fffff018313811615613a2757613a276138b5565b600060208284031215613bce57600080fd5b81516134ea81613664565b6000815180845260005b81811015613bff57602081850181015186830182015201613be3565b81811115613c11576000602083870101525b50601f01601f19169290920160200192915050565b6020815260006134ea6020830184613bd9565b604081526000613c4c6040830185613bd9565b90508260208301529392505050565b600060208284031215613c6d57600080fd5b5051919050565b600081600f0b83600f0b60016001607f1b03600082136000841383830485118282161615613ca457613ca46138b5565b60016001607f1b03196000851282811687830587121615613ac457613ac46138b5565b600081600f0b83600f0b80613cde57613cde613918565b60016001607f1b0319821460001982141615613b3757613b376138b556fe2d2d20535441525420414343554d554c415445204c41535420424c4f434b202d2d2d2d204541524c5920454e4420414343554d554c415445204c41535420424c4f434b202d2da26469706673582212208ef18c34e04a49bac7790202130798ab6934e22270d7f3e3011d54085cd063c064736f6c634300080d0033";

type TicksConstructorParams =
  | [linkLibraryAddresses: TicksLibraryAddresses, signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TicksConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => {
  return (
    typeof xs[0] === "string" ||
    (Array.isArray as (arg: any) => arg is readonly any[])(xs[0]) ||
    "_isInterface" in xs[0]
  );
};

export class Ticks__factory extends ContractFactory {
  constructor(...args: TicksConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      const [linkLibraryAddresses, signer] = args;
      super(_abi, Ticks__factory.linkBytecode(linkLibraryAddresses), signer);
    }
  }

  static linkBytecode(linkLibraryAddresses: TicksLibraryAddresses): string {
    let linkedBytecode = _bytecode;

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$b52f7ddb7db4526c8b5c81c46a9292f776\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/TickMath.sol:TickMath"]
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
  ): Promise<Ticks> {
    return super.deploy(overrides || {}) as Promise<Ticks>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): Ticks {
    return super.attach(address) as Ticks;
  }
  connect(signer: Signer): Ticks__factory {
    return super.connect(signer) as Ticks__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TicksInterface {
    return new utils.Interface(_abi) as TicksInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Ticks {
    return new Contract(address, _abi, signerOrProvider) as Ticks;
  }
}

export interface TicksLibraryAddresses {
  ["contracts/libraries/TickMath.sol:TickMath"]: string;
  ["contracts/libraries/DyDxMath.sol:DyDxMath"]: string;
  ["contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"]: string;
}
