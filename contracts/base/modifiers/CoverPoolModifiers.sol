// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import '../storage/CoverPoolStorage.sol';
import '../../libraries/Ticks.sol';

abstract contract CoverPoolModifiers is CoverPoolStorage {
    modifier lock() {
        if (globalState.unlocked == 0) {
            globalState = Ticks.initialize(tickMap, pool0, pool1, globalState);
        }
        if (globalState.unlocked == 0) revert WaitUntilEnoughObservations();
        if (globalState.unlocked == 2) revert Locked();
        globalState.unlocked = 2;
        _;
        globalState.unlocked = 1;
    }

    modifier onlyFactory(address _factory) {
        if (_factory != msg.sender) revert FactoryOnly();
        _;
    }
}