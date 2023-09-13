// SPDX-License-Identifier: GPLv3
pragma solidity 0.8.13;

import "../math/OverflowMath.sol";
import '../../interfaces/IPositionERC1155.sol';
import "../../interfaces/cover/ICoverPoolFactory.sol";
import "../../interfaces/structs/CoverPoolStructs.sol";

/// @notice Token library for ERC-1155 calls.
library PositionTokens {
    function balanceOf(
        PoolsharkStructs.CoverImmutables memory constants,
        address owner,
        uint32 positionId
    ) internal view returns (
        uint256
    )
    {
        return IPositionERC1155(constants.poolToken).balanceOf(owner, positionId);
    }
}