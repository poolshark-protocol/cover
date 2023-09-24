// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

abstract contract TwapSourceEvents {
    event SampleCountInitialized (
        address indexed coverPool,
        uint16 sampleCount,
        uint16 sampleCountMax,
        uint16 sampleCountRequired
    );
}
