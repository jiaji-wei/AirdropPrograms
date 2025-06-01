// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { AirdropPrograms } from "../src/AirdropPrograms.sol";

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "./Base.s.sol";
import { UnsafeUpgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/guides/scripting-with-solidity
contract Deploy is BaseScript {
    function run() public broadcast returns (AirdropPrograms airdropPrograms) {
        address DEFAULT_ADMIN_ADDRESS = 0x072D3795e78265F3870314F7B25b818B2BC6384E;
        address MAINTAINER_ADDRESS = 0x072D3795e78265F3870314F7B25b818B2BC6384E;

        airdropPrograms = new AirdropPrograms();

        address proxy = UnsafeUpgrades.deployUUPSProxy(
            address(airdropPrograms),
            abi.encodeCall(AirdropPrograms.initialize, (DEFAULT_ADMIN_ADDRESS, MAINTAINER_ADDRESS))
        );

        console2.log("AirdropPrograms implementation deployed to:", address(airdropPrograms));
        console2.log("AirdropPrograms proxy deployed to:", proxy);
        console2.log("AirdropPrograms initialized with:", DEFAULT_ADMIN_ADDRESS, MAINTAINER_ADDRESS);

        return AirdropPrograms(proxy);
    }
}
