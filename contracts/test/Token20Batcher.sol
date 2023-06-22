//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import './Token20.sol';

contract Token20Batcher {

    constructor(){}

    function mintBatch(
        address[] calldata tokens,
        address[] calldata to,
        uint256 amount
    ) external {
        for (uint i = 0; i < to.length ; i++) {
            for (uint j = 0; j < tokens.length; j++) {
                Token20(tokens[j]).mint(to[i], amount);
            }
        }
    }
}
