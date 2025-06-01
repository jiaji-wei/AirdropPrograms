// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IAirdropPrograms {
    function claimRewards(bytes32 id, address user, uint256 amount, bytes32[] calldata proof) external;

    function batchClaimRewards(
        bytes32[] calldata ids,
        address[] calldata users,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    )
        external;

    function createAirdrop(
        bytes32 id,
        address token,
        bytes32 root,
        uint256 totalAmount,
        uint128 startTimestamp,
        uint128 endTimestamp
    )
        external;

    function updateAirdrop(
        bytes32 id,
        address token,
        bytes32 root,
        uint256 totalAmount,
        uint128 startTimestamp,
        uint128 endTimestamp
    )
        external;

    function disperseToken(IERC20 token, address[] calldata recipients, uint256[] calldata values) external;

    function pauseAirdropById(bytes32 id) external;

    function isUserClaimed(address user, bytes32[] calldata ids) external view returns (bool[] memory);
}
