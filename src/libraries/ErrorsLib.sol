// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

library ErrorsLib {
    error InvalidAdminOrMaintainer();

    error InvalidAirdropParameters();
    error InvalidAirdropAmount();
    error InvalidProof();

    error AirdropDoesNotExist(bytes32 id);
    error AirdropAlreadyExists(bytes32 id);
    error AirdropIsNotActive(bytes32 id);
    error AirdropAlreadyClaimed(bytes32 id);
    error AirdropAmountExceeded(bytes32 id);
}
