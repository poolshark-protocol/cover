// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import '../interfaces/structs/PoolsharkStructs.sol';
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IPositionERC1155 is IERC165, PoolsharkStructs {
    event TransferSingle(
        address indexed sender,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed sender,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed account,
        address indexed sender,
        bool approve
    );

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (
        uint256[] memory batchBalances
    );

    function totalSupply(uint256 id) external view returns (uint256);

    function isApprovedForAll(address owner, address spender) external view returns (bool);

    function setApprovalForAll(address sender, bool approved) external;

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        PoolsharkStructs.CoverImmutables memory constants
    ) external;

    function burn(
        address account,
        uint256 id,
        uint256 amount,
        PoolsharkStructs.CoverImmutables memory constants
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata id,
        uint256[] calldata amount
    ) external;
}