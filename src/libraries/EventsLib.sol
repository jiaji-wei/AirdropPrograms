// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

library EventsLib {
    event AirdropCreated(
        bytes32 id, address token, bytes32 root, uint256 totalAmount, uint128 startTimestamp, uint128 endTimestamp
    );

    event AirdropUpdated(
        bytes32 id, address token, bytes32 root, uint256 totalAmount, uint128 startTimestamp, uint128 endTimestamp
    );

    event AirdropPaused(bytes32 id);

    event AirdropClaimed(bytes32 id, address user, address token, uint256 amount);
}
