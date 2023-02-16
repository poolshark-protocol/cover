/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type { Epochs, EpochsInterface } from "../Epochs";

const _abi = [
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "InfiniteTickLoop0",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "int24",
        name: "",
        type: "int24",
      },
    ],
    name: "InfiniteTickLoop1",
    type: "error",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "int24",
            name: "nextTickToCross0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToCross1",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToAccum0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToAccum1",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "stopTick0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "stopTick1",
            type: "int24",
          },
          {
            internalType: "uint128",
            name: "amountInDelta0",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountInDelta1",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountOutDelta0",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountOutDelta1",
            type: "uint128",
          },
        ],
        internalType: "struct ICoverPoolStructs.AccumulateCache",
        name: "cache",
        type: "tuple",
      },
      {
        internalType: "uint256",
        name: "currentPrice",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentLiquidity",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "isPool0",
        type: "bool",
      },
    ],
    name: "rollover",
    outputs: [
      {
        components: [
          {
            internalType: "int24",
            name: "nextTickToCross0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToCross1",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToAccum0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "nextTickToAccum1",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "stopTick0",
            type: "int24",
          },
          {
            internalType: "int24",
            name: "stopTick1",
            type: "int24",
          },
          {
            internalType: "uint128",
            name: "amountInDelta0",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountInDelta1",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountOutDelta0",
            type: "uint128",
          },
          {
            internalType: "uint128",
            name: "amountOutDelta1",
            type: "uint128",
          },
        ],
        internalType: "struct ICoverPoolStructs.AccumulateCache",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
];

const _bytecode =
  "0x613b0f61003a600b82828239805160001a60731461002d57634e487b7160e01b600052600060045260246000fd5b30600052607381538281f3fe73000000000000000000000000000000000000000030146080604052600436106100405760003560e01c80631497bce4146100455780634d97e98e1461006e575b600080fd5b6100586100533660046131d7565b61009d565b604051610065919061322f565b60405180910390f35b81801561007a57600080fd5b5061008e61008936600461348f565b6100d0565b60405161006593929190613622565b6100a56130f6565b60006100b636879003870187613745565b90506100c481868686612278565b9150505b949350505050565b604080516101a0810182526000808252602080830182905282840182905260608084018390526080840183905260a0840183905260c0840183905260e084018390526101008401839052610120840183905261014084018390526101608401839052610180840183905284519081018552828152908101829052928301529060408051606081018252600080825260208201819052918101919091526101808401516060850151604051634fc65aeb60e11b81526001600160a01b03909216600483015261ffff16602482015260009073__$657d9a64028a7d57fe1695a914827e9925$__90639f8cb5d690604401602060405180830381865af41580156101dc573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610200919061380d565b63ffffffff431660e0870152604086015160a08701519192506102299160019190910b9061385d565b60020b856040015160010b8261023f919061385d565b60020b03610256578487879350935093505061226c565b6001856101200181815161026a9190613897565b63ffffffff16905250604080516101408101825260a087018051600290810b83528151810b6020808501919091528251820b60009081528d825285812054830b858701528351830b8152908d90529384205463010000009004810b60608401529051608083019190810b9085900b136102e357836102fa565b876040015160010b8860a001516102fa91906138bf565b60020b81526020018760a0015160020b8460020b1361032f57876040015160010b8860a0015161032a9190613907565b610331565b835b60020b815260208a8101516001600160801b0390811682840152908a015116604082015260006060820181905260809091015290505b87516001600160801b031615610aef5761039e8189604001516001600160a01b03168a600001516001600160801b03166001612278565b90506103a861314a565b6107438a6000846040015160020b60020b81526020019081526020016000206040518060600160405290816000820160009054906101000a900460020b60020b60020b81526020016000820160039054906101000a900460020b60020b60020b81526020016000820160069054906101000a900463ffffffff1663ffffffff1663ffffffff16815250508d6000856000015160020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b0316815250508e6000866040015160020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b0316815250508a61012001518d600001518760c0015188610100015160018f60a0015160020b8c60020b1361072d578a6080015160020b8b6040015160020b1361292e565b8a6080015160020b8b6040015160020b1261292e565b905080600001518260c001906001600160801b031690816001600160801b03168152505080602001518261010001906001600160801b031690816001600160801b03168152505080604001518a6000846040015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff16021790555090505080606001518c6000846000015160020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b0316021790555090505080608001518c6000846040015160020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b0316021790555090505050610aff565b600060c082018190526101008201525b806080015160020b816040015160020b1315610bde5760408181018051600290810b600090815260208d81528482208551606081018752905480850b825263010000008104850b82840152600160301b900463ffffffff1681870152845190930b82528f90529290922054835191518b51610b859493600f9390930b9291906001612dec565b600290810b6040850190815291810b84526001600160801b039092168a5251825190820b910b03610bd957604080820151905162a7a77b60e71b815260029190910b60048201526024015b60405180910390fd5b610367565b8560a0015160020b8260020b1315610d5257806080015160020b816040015160020b14610d52576040518060600160405280826040015160020b8152602001826000015160020b8152602001600063ffffffff16815250896000836080015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff1602179055509050508060800151896000836040015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff1602179055508060800151896000836000015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff1602179055505b608080820151600290810b600090815260208e8152604091829020825160e0810184528154600f81900b82526001600160801b03600160801b918290048116948301949094526001808401548086169684019690965294819004841660608301529190940154918216948401949094526001600160401b03938104841660a0840152600160c01b900490921660c08201528951610df192849190612e4c565b608082810151600290810b600090815260208f81526040918290208551918601516001600160801b03928316600160801b9184168202178255928601516060870151908316908316840217600182015593850151938301805460a08088015160c090980151969093166001600160c01b0319909116176001600160401b03968716909302929092176001600160c01b0316600160c01b95909416949094029290921790915590870151810b9083900b1215610f4457806080015160020b816040015160020b12610f445760408181018051600290810b600090815260208d81528482208551606081018752905480850b825263010000008104850b82840152600160301b900463ffffffff1681870152845190930b82528f90529290922054835191518b51610f2b9493600f9390930b9291906001612dec565b600290810b60408501520b82526001600160801b031688525b608081018051600290810b600090815260208e90526040808220548451840b835281832060010180546001600160801b0319166001600160801b03600160801b938490048116919091179091558551850b845282842054955190940b83529082208054919094049092169291610fbe908490600f0b61394e565b92506101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060008b6000836080015160020b60020b815260200190815260200160002060000160106101000a8154816001600160801b0302191690836001600160801b03160217905550856101200151896000836080015160020b60020b815260200190815260200160002060000160066101000a81548163ffffffff021916908363ffffffff1602179055505b86516001600160801b0316156117f6576110a58188604001516001600160a01b031689600001516001600160801b03166000612278565b90506110af61314a565b61144a8a6000846060015160020b60020b81526020019081526020016000206040518060600160405290816000820160009054906101000a900460020b60020b60020b81526020016000820160039054906101000a900460020b60020b60020b81526020016000820160069054906101000a900463ffffffff1663ffffffff1663ffffffff16815250508c6000856020015160020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b0316815250508d6000866060015160020b60020b81526020019081526020016000206040518060e00160405290816000820160009054906101000a9004600f0b600f0b600f0b81526020016000820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016001820160109054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160009054906101000a90046001600160801b03166001600160801b03166001600160801b031681526020016002820160109054906101000a90046001600160401b03166001600160401b03166001600160401b031681526020016002820160189054906101000a90046001600160401b03166001600160401b03166001600160401b0316815250508a61012001518c600001518760e0015188610120015160018f60a0015160020b8c60020b13611434578a60a0015160020b8b6060015160020b1361292e565b8a60a0015160020b8b6060015160020b1261292e565b905080600001518260e001906001600160801b031690816001600160801b03168152505080602001518261012001906001600160801b031690816001600160801b03168152505080604001518a6000846060015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff16021790555090505080606001518b6000846020015160020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b0316021790555090505080608001518b6000846060015160020b60020b815260200190815260200160002060008201518160000160006101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060208201518160000160106101000a8154816001600160801b0302191690836001600160801b0316021790555060408201518160010160006101000a8154816001600160801b0302191690836001600160801b0316021790555060608201518160010160106101000a8154816001600160801b0302191690836001600160801b0316021790555060808201518160020160006101000a8154816001600160801b0302191690836001600160801b0316021790555060a08201518160020160106101000a8154816001600160401b0302191690836001600160401b0316021790555060c08201518160020160186101000a8154816001600160401b0302191690836001600160401b0316021790555090505050611806565b600060e082018190526101208201525b8060a0015160020b816060015160020b12156118e65760608181018051600290810b600090815260208d81526040808320815196870182525480850b875263010000008104850b87840152600160301b900463ffffffff1686820152845190930b82528e8152918120549185015192518b5161188a9594600f9490940b9392612dec565b600290810b6060850190815291810b602085019081526001600160801b039093168a529051915191810b91900b036118e157602081015160405163550e7ea560e11b815260029190910b6004820152602401610bd0565b61106e565b8560a0015160020b8260020b1215611a5a578060a0015160020b816060015160020b14611a5a576040518060600160405280826020015160020b8152602001826060015160020b8152602001600063ffffffff168152508960008360a0015160020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff1602179055509050508060a00151896000836020015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff1602179055508060a00151896000836060015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff1602179055505b60a080820151600290810b600090815260208d81526040808320815160e0810183528154600f81900b82526001600160801b03600160801b91829004811695830195909552600183015480861694830194909452928390048416606082015294015491821660808501526001600160401b03908204811694840194909452600160c01b900490921660c08201528851611af592849190612e4c565b60a082810151600290810b600090815260208e81526040918290208551918601516001600160801b03928316600160801b91841682021782559286015160608701519083169083168402176001820155608086015190840180548787015160c090980151929093166001600160c01b0319909316929092176001600160401b03968716909302929092176001600160c01b0316600160c01b959092169490940217909255870151810b9083900b1315611daf578160020b816060015160020b14611cfe576040518060600160405280826020015160020b8152602001826060015160020b815260200187610120015163ffffffff168152508960008460020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff16021790555090505081896000836020015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff16021790555081896000836060015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff1602179055505b8060a0015160020b816060015160020b13611d9d5760608181018051600290810b600090815260208d81526040808320815196870182525480850b875263010000008104850b87840152600160301b900463ffffffff1686820152845190930b82528e8152918120549185015192518b51611d819594600f9490940b9392612dec565b600290810b60608501520b60208301526001600160801b031687525b6000885286516001600160801b031687525b60a081018051600290810b600090815260208d90526040808220548451840b835281832060010180546001600160801b0319166001600160801b03600160801b938490048116919091179091558551850b845282842054955190940b83529082208054919094049092169291611e29908490600f0b61394e565b92506101000a8154816001600160801b030219169083600f0b6001600160801b0316021790555060008a60008360a0015160020b60020b815260200190815260200160002060000160106101000a8154816001600160801b0302191690836001600160801b031602179055508561012001518960008360a0015160020b60020b815260200190815260200160002060000160066101000a81548163ffffffff021916908363ffffffff1602179055508560a0015160020b8260020b13612063578560a0015160020b8260020b1215612063578160020b816000015160020b14612051576040518060600160405280826040015160020b8152602001826000015160020b815260200187610120015163ffffffff168152508960008460020b60020b815260200190815260200160002060008201518160000160006101000a81548162ffffff021916908360020b62ffffff16021790555060208201518160000160036101000a81548162ffffff021916908360020b62ffffff16021790555060408201518160000160066101000a81548163ffffffff021916908363ffffffff16021790555090505081896000836040015160020b60020b815260200190815260200160002060000160036101000a81548162ffffff021916908360020b62ffffff16021790555081896000836000015160020b60020b815260200190815260200160002060000160006101000a81548162ffffff021916908360020b62ffffff1602179055505b87516001600160801b03168852600087525b73__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3876040015160010b8461209091906138bf565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af41580156120cf573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906120f39190613994565b6001600160a01b03166040808a019190915286015173__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba3906121319060010b85613907565b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af4158015612170573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906121949190613994565b6001600160a01b0316604088015260006020808a0182905288015260c08601516121c49063ffffffff16436139b1565b63ffffffff16610100870152600282900b60a0870181905260405163986cfba360e01b8152600481019190915273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af415801561222d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906122519190613994565b6001600160a01b031661016087015250849350869250859150505b96509650969350505050565b6122806130f6565b8260000361228f5750836100c8565b600073__$b52f7ddb7db4526c8b5c81c46a9292f776$__63986cfba3846122ba5787602001516122bd565b87515b6040516001600160e01b031960e084901b16815260029190910b6004820152602401602060405180830381865af41580156122fc573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906123209190613994565b9050600080841561235757876080015160020b886040015160020b1261234a578760400151612350565b87608001515b905061237f565b8760a0015160020b886060015160020b1361237657876060015161237c565b8760a001515b90505b60405163986cfba360e01b8152600282900b600482015273__$b52f7ddb7db4526c8b5c81c46a9292f776$__9063986cfba390602401602060405180830381865af41580156123d2573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906123f69190613994565b9150508361240f57806001600160a01b0316861061241c565b806001600160a01b031686115b1561242e57806001600160a01b031695505b600080851561256357604051639026147360e01b815260048101889052602481018990526001600160a01b03851660448201526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af41580156124a4573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906124c891906139c8565b604051630724718960e41b815260048101899052602481018a90526001600160a01b03861660448201526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af4158015612538573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061255c91906139c8565b915061268b565b604051630724718960e41b8152600481018890526001600160a01b0385166024820152604481018990526000606482015273__$357eccfa53a4e88c122661903e0e603301$__90637247189090608401602060405180830381865af41580156125d0573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906125f491906139c8565b604051639026147360e01b8152600481018990526001600160a01b0386166024820152604481018a90526000606482015290915073__$357eccfa53a4e88c122661903e0e603301$__90639026147390608401602060405180830381865af4158015612664573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061268891906139c8565b91505b85156127db5760405163554d048960e11b815260048101839052600160601b60248201526044810188905273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af41580156126f2573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061271691906139c8565b8960c00181815161272791906139e1565b6001600160801b031690525060405163554d048960e11b815260048101829052600160601b60248201526044810188905273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af4158015612794573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906127b891906139c8565b89610100018181516127ca91906139e1565b6001600160801b0316905250612921565b60405163554d048960e11b815260048101839052600160601b60248201526044810188905273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af415801561283c573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061286091906139c8565b8960e00181815161287191906139e1565b6001600160801b031690525060405163554d048960e11b815260048101829052600160601b60248201526044810188905273__$1b9fef1800622f5f6a93914ffdeb7ba32f$__9063aa9a091290606401602060405180830381865af41580156128de573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061290291906139c8565b896101200181815161291491906139e1565b6001600160801b03169052505b5096979650505050505050565b61293661314a565b60208801516001600160801b0316156129565763ffffffff871660408b01525b6001600160801b03861615612c4257602089015189516000916129789161394e565b9050600073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__63aa9a0912886129a1858c613a03565b6040516001600160e01b031960e085901b1681526001600160801b03928316600482015291166024820152600160601b6044820152606401602060405180830381865af41580156129f6573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612a1a91906139c8565b9050600073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__63aa9a091288612a43868d613a03565b6040516001600160e01b031960e085901b1681526001600160801b03928316600482015291166024820152600160601b6044820152606401602060405180830381865af4158015612a98573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612abc91906139c8565b90506000836001600160801b0316118015612ae85750826001600160801b0316896001600160801b0316115b15612c3e5773__$1b9fef1800622f5f6a93914ffdeb7ba32f$__63aa9a091283600160601b8e604001518d612b1d91906139e1565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526001600160801b03166044820152606401602060405180830381865af4158015612b6f573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612b9391906139c8565b975073__$1b9fef1800622f5f6a93914ffdeb7ba32f$__63aa9a091282600160601b8e604001518d612bc591906139e1565b6040516001600160e01b031960e086901b168152600481019390935260248301919091526001600160801b03166044820152606401602060405180830381865af4158015612c17573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190612c3b91906139c8565b96505b5050505b60a08901516001600160401b031615612d49576000670de0b6b3a76400008a606001516001600160801b03168b60a001516001600160401b0316612c869190613a2b565b612c909190613a4a565b9050808a606001818151612ca49190613a03565b6001600160801b0316905250600060a08b0152612cc181876139e1565b60c08b01519096506001600160401b031615612d47576000670de0b6b3a76400008b608001516001600160801b03168c60c001516001600160401b0316612d089190613a2b565b612d129190613a4a565b9050808b608001818151612d269190613a03565b6001600160801b0316905250600060c08c0152612d4381876139e1565b9550505b505b8215612d6b576020890180516001600160801b031660408b01526000808b5290525b8115612db0578488606001818151612d8391906139e1565b6001600160801b0316905250608088018051859190612da39083906139e1565b6001600160801b03169052505b50506040805160a0810182526001600160801b039485168152929093166020830152509081019590955250506060830191909152608082015290565b6000806000859650600088600f0b1315612e1157612e0a88866139e1565b9450612e27565b612e1a88613a5e565b612e249086613a03565b94505b8315612e365788519550612e3e565b886020015195505b509297949650929450505050565b612e5461319b565b826001600160801b0316600003612e6c5750836100c8565b600082612e7d578460e00151612e83565b8460c001515b90506000670de0b6b3a764000087606001518860a001516001600160401b0316612ead9190613a84565b612eb79190613ab3565b90506000876060015183612ecb91906139e1565b90506001600160801b03831615612fa45787602001516001600160801b0316866001600160801b031603612f3d57806001600160801b0316826001600160801b0316670de0b6b3a7640000612f209190613a2b565b612f2a9190613a4a565b6001600160401b031660a0890152612f85565b6001600160801b038116612f5183856139e1565b612f6c906001600160801b0316670de0b6b3a7640000613a2b565b612f769190613a4a565b6001600160401b031660a08901525b8288606001818151612f9791906139e1565b6001600160801b03169052505b505050600082612fb957846101200151612fc0565b8461010001515b90506000670de0b6b3a764000087608001516001600160801b03168860c001516001600160401b0316612ff39190613a2b565b612ffd9190613a4a565b9050600082886080015161301191906139e1565b90506001600160801b038316156130ea5787602001516001600160801b0316866001600160801b03160361308357806001600160801b0316826001600160801b0316670de0b6b3a76400006130669190613a2b565b6130709190613a4a565b6001600160401b031660c08901526130cb565b6001600160801b03811661309783856139e1565b6130b2906001600160801b0316670de0b6b3a7640000613a2b565b6130bc9190613a4a565b6001600160401b031660c08901525b82886080018181516130dd91906139e1565b6001600160801b03169052505b50959695505050505050565b6040805161014081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c0810182905260e08101829052610100810182905261012081019190915290565b6040805160a08101825260008082526020808301829052835160608082018652838252918101839052808501929092529282015290810161318961319b565b815260200161319661319b565b905290565b6040805160e081018252600080825260208201819052918101829052606081018290526080810182905260a0810182905260c081019190915290565b6000806000808486036101a08112156131ef57600080fd5b610140808212156131ff57600080fd5b8695508501359350506101608401359150610180840135801515811461322457600080fd5b939692955090935050565b815160020b81526101408101602083015161324f602084018260020b9052565b506040830151613264604084018260020b9052565b506060830151613279606084018260020b9052565b50608083015161328e608084018260020b9052565b5060a08301516132a360a084018260020b9052565b5060c08301516132be60c08401826001600160801b03169052565b5060e08301516132d960e08401826001600160801b03169052565b50610100838101516001600160801b03908116918401919091526101209384015116929091019190915290565b6040516101a081016001600160401b038111828210171561333757634e487b7160e01b600052604160045260246000fd5b60405290565b60405161014081016001600160401b038111828210171561333757634e487b7160e01b600052604160045260246000fd5b80356001600160801b038116811461338557600080fd5b919050565b6001600160a01b038116811461339f57600080fd5b50565b80356133858161338a565b6000606082840312156133bf57600080fd5b604051606081018181106001600160401b03821117156133ef57634e487b7160e01b600052604160045260246000fd5b6040529050806133fe8361336e565b815261340c6020840161336e565b6020820152604083013561341f8161338a565b6040919091015292915050565b803560ff8116811461338557600080fd5b803561ffff8116811461338557600080fd5b8035600181900b811461338557600080fd5b8060020b811461339f57600080fd5b803561338581613461565b803563ffffffff8116811461338557600080fd5b6000806000806000808688036102c08112156134aa57600080fd5b8735965060208801359550604088013594506134c98960608a016133ad565b93506134d88960c08a016133ad565b92506101206101a08061011f19840112156134f257600080fd5b6134fa613306565b9250613507828b0161342c565b8352610140613517818c0161343d565b602085015261016061352a818d0161344f565b604086015261018061353d818e0161343d565b606087015261354d848e0161343d565b608087015261355f6101c08e01613470565b60a08701526135716101e08e0161347b565b60c08701526135836102008e0161347b565b60e08701526135956102208e0161347b565b6101008701526135a86102408e0161347b565b858701526135b96102608e0161336e565b838701526135ca6102808e016133a2565b828701526135db6102a08e016133a2565b818701525050505050809150509295509295509295565b80516001600160801b039081168352602080830151909116908301526040908101516001600160a01b0316910152565b835160ff16815261026081016020850151613643602084018261ffff169052565b506040850151613658604084018260010b9052565b50606085015161366e606084018261ffff169052565b506080850151613684608084018261ffff169052565b5060a085015161369960a084018260020b9052565b5060c08501516136b160c084018263ffffffff169052565b5060e08501516136c960e084018263ffffffff169052565b506101008581015163ffffffff908116918401919091526101208087015190911690830152610140808601516001600160801b031690830152610160808601516001600160a01b039081169184019190915261018080870151909116908301526137376101a08301856135f2565b6100c86102008301846135f2565b6000610140828403121561375857600080fd5b61376061333d565b61376983613470565b815261377760208401613470565b602082015261378860408401613470565b604082015261379960608401613470565b60608201526137aa60808401613470565b60808201526137bb60a08401613470565b60a08201526137cc60c0840161336e565b60c08201526137dd60e0840161336e565b60e08201526101006137f081850161336e565b9082015261012061380284820161336e565b908201529392505050565b60006020828403121561381f57600080fd5b815161382a81613461565b9392505050565b634e487b7160e01b600052601260045260246000fd5b634e487b7160e01b600052601160045260246000fd5b60008160020b8360020b8061387457613874613831565b627fffff1982146000198214161561388e5761388e613847565b90059392505050565b600063ffffffff8083168185168083038211156138b6576138b6613847565b01949350505050565b60008160020b8360020b6000811281627fffff19018312811516156138e6576138e6613847565b81627fffff0183138116156138fd576138fd613847565b5090039392505050565b60008160020b8360020b6000821282627fffff0382138115161561392d5761392d613847565b82627fffff1903821281161561394557613945613847565b50019392505050565b600081600f0b83600f0b600082128260016001607f1b030382138115161561397857613978613847565b8260016001607f1b031903821281161561394557613945613847565b6000602082840312156139a657600080fd5b815161382a8161338a565b6000828210156139c3576139c3613847565b500390565b6000602082840312156139da57600080fd5b5051919050565b60006001600160801b038083168185168083038211156138b6576138b6613847565b60006001600160801b0383811690831681811015613a2357613a23613847565b039392505050565b6000816000190483118215151615613a4557613a45613847565b500290565b600082613a5957613a59613831565b500490565b600081600f0b60016001607f1b03198103613a7b57613a7b613847565b60000392915050565b60006001600160801b0380831681851681830481118215151615613aaa57613aaa613847565b02949350505050565b60006001600160801b0380841680613acd57613acd613831565b9216919091049291505056fea26469706673582212206eda9f1ec3c7d0297afb4aae0ebdd2f0537ccd9ef993dccc1f2d9aee61b73eda64736f6c634300080d0033";

type EpochsConstructorParams =
  | [linkLibraryAddresses: EpochsLibraryAddresses, signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: EpochsConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => {
  return (
    typeof xs[0] === "string" ||
    (Array.isArray as (arg: any) => arg is readonly any[])(xs[0]) ||
    "_isInterface" in xs[0]
  );
};

export class Epochs__factory extends ContractFactory {
  constructor(...args: EpochsConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      const [linkLibraryAddresses, signer] = args;
      super(_abi, Epochs__factory.linkBytecode(linkLibraryAddresses), signer);
    }
  }

  static linkBytecode(linkLibraryAddresses: EpochsLibraryAddresses): string {
    let linkedBytecode = _bytecode;

    linkedBytecode = linkedBytecode.replace(
      new RegExp("__\\$657d9a64028a7d57fe1695a914827e9925\\$__", "g"),
      linkLibraryAddresses["contracts/libraries/TwapOracle.sol:TwapOracle"]
        .replace(/^0x/, "")
        .toLowerCase()
    );

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
  ): Promise<Epochs> {
    return super.deploy(overrides || {}) as Promise<Epochs>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): Epochs {
    return super.attach(address) as Epochs;
  }
  connect(signer: Signer): Epochs__factory {
    return super.connect(signer) as Epochs__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): EpochsInterface {
    return new utils.Interface(_abi) as EpochsInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Epochs {
    return new Contract(address, _abi, signerOrProvider) as Epochs;
  }
}

export interface EpochsLibraryAddresses {
  ["contracts/libraries/TwapOracle.sol:TwapOracle"]: string;
  ["contracts/libraries/TickMath.sol:TickMath"]: string;
  ["contracts/libraries/DyDxMath.sol:DyDxMath"]: string;
  ["contracts/libraries/FullPrecisionMath.sol:FullPrecisionMath"]: string;
}
