// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { AirdropPrograms } from "../src/AirdropPrograms.sol";

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "./Base.s.sol";

contract CreateAirdrop is BaseScript {
    function run() public broadcast {
        address airdropProgramsAddress = 0x072D3795e78265F3870314F7B25b818B2BC6384E;

        AirdropPrograms airdropPrograms = AirdropPrograms(airdropProgramsAddress);

        bytes32 id = keccak256(abi.encode("rewardProgram1"));
        address token = 0x072D3795e78265F3870314F7B25b818B2BC6384E;
        bytes32 root = 0x94db223bc258685d042fd185e22c491041134232fbdcad412cf2abf22ef28a06;
        uint256 totalAmount = 12 ether;
        uint128 startTimestamp = 1_748_707_200; // 2025-06-01 00:00:00
        uint128 endTimestamp = 1_749_657_600; // 2025-06-12 00:00:00

        airdropPrograms.createAirdrop(id, token, root, totalAmount, startTimestamp, endTimestamp);

        console2.log("Airdrop created with id:");
        console2.logBytes32(id);

        console2.log("Airdrop created with token:");
        console2.logAddress(token);

        console2.log("Airdrop created with root:");
        console2.logBytes32(root);

        console2.log("Airdrop created with total amount:");
        console2.logUint(totalAmount);

        console2.log("Airdrop created with start timestamp:");
        console2.logUint(startTimestamp);

        console2.log("Airdrop created with end timestamp:");
        console2.logUint(endTimestamp);
    }
}
