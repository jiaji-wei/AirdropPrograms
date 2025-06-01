// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Merkle } from "murky/Merkle.sol";

import { TestToken } from "../src/test/TestToken.sol";
import { AirdropPrograms } from "../src/AirdropPrograms.sol";

contract AirdropProgramsTest is Test {
    AirdropPrograms internal airdropPrograms;
    TestToken internal testToken;

    address internal defaultAdmin = vm.addr(10_000);
    address internal defaultMaintainer = vm.addr(20_000);

    function setUp() public virtual {
        AirdropPrograms logic = new AirdropPrograms();
        airdropPrograms = AirdropPrograms(
            address(
                new ERC1967Proxy(
                    address(logic),
                    abi.encodeWithSelector(AirdropPrograms.initialize.selector, defaultAdmin, defaultMaintainer)
                )
            )
        );

        testToken = new TestToken(defaultMaintainer);

        vm.prank(defaultMaintainer);
        testToken.mint(defaultMaintainer, 21 ether);

        vm.prank(defaultMaintainer);
        testToken.approve(address(airdropPrograms), 21 ether);
    }

    function encodeLeaf(bytes32 _id, address _address, uint256 _amount) public pure returns (bytes32) {
        return keccak256(abi.encode(_id, _address, _amount));
    }

    function test_createAirdrop() public {
        vm.prank(defaultMaintainer);

        bytes32 id = keccak256(abi.encode("rewardProgram1"));
        uint256 totalAmount = 21 ether;
        uint128 startTimestamp = uint128(block.timestamp) - 1;
        uint128 endTimestamp = uint128(block.timestamp + 1 days);

        Merkle m = new Merkle();
        bytes32[] memory list = new bytes32[](6);
        list[0] = encodeLeaf(id, vm.addr(1), 1 ether);
        list[1] = encodeLeaf(id, vm.addr(2), 2 ether);
        list[2] = encodeLeaf(id, vm.addr(3), 3 ether);
        list[3] = encodeLeaf(id, vm.addr(4), 4 ether);
        list[4] = encodeLeaf(id, vm.addr(5), 5 ether);
        list[5] = encodeLeaf(id, vm.addr(6), 6 ether);

        bytes32 root = m.getRoot(list);

        vm.prank(defaultMaintainer);
        airdropPrograms.createAirdrop(id, address(testToken), root, totalAmount, startTimestamp, endTimestamp);

        AirdropPrograms.Airdrop memory program = airdropPrograms.getAirdrop(id);
        assertEq(program.token, address(testToken));
        assertEq(program.totalAmount, totalAmount);
        assertEq(program.startTimestamp, startTimestamp);
        assertEq(program.endTimestamp, endTimestamp);
    }

    function test_MerkleRoot() public {
        Merkle m = new Merkle();

        bytes32 id = keccak256(abi.encode("rewardProgram1"));
        uint256 totalAmount = 21 ether;
        uint128 startTimestamp = uint128(block.timestamp) - 1;
        uint128 endTimestamp = uint128(block.timestamp + 1 days);

        //create an array of elements to put in the Merkle tree
        bytes32[] memory list = new bytes32[](6);
        list[0] = encodeLeaf(id, vm.addr(1), 1 ether);
        list[1] = encodeLeaf(id, vm.addr(2), 2 ether);
        list[2] = encodeLeaf(id, vm.addr(3), 3 ether);
        list[3] = encodeLeaf(id, vm.addr(4), 4 ether);
        list[4] = encodeLeaf(id, vm.addr(5), 5 ether);
        list[5] = encodeLeaf(id, vm.addr(6), 6 ether);

        //compute the merkle root
        bytes32 root = m.getRoot(list);

        vm.prank(defaultMaintainer);
        airdropPrograms.createAirdrop(id, address(testToken), root, totalAmount, startTimestamp, endTimestamp);

        // Check for valid addresses
        for (uint8 i = 0; i < 6; i++) {
            bytes32[] memory proof = m.getProof(list, i);
            vm.prank(vm.addr(i + 1));
            bool verified = airdropPrograms.checkProof(id, vm.addr(i + 1), (1 + i) * 1 ether, proof);

            assertEq(verified, true);
        }

        //make an empty bytes32 array as an invalid proof
        bytes32[] memory invalidProof;

        // Check for invalid addresses
        bool verifiedInvalid = airdropPrograms.checkProof(id, vm.addr(1), 1 ether, invalidProof);
        assertEq(verifiedInvalid, false);
    }

    function test_claimAirdrop() public {
        (bytes32 id,, bytes32[] memory list, Merkle m) = initAirdrop();

        for (uint8 i = 0; i < 6; i++) {
            vm.prank(vm.addr(i + 1));
            bytes32[] memory proof = m.getProof(list, i);
            airdropPrograms.claimRewards(id, vm.addr(i + 1), (1 + i) * 1 ether, proof);

            assertEq(testToken.balanceOf(vm.addr(i + 1)), (1 + i) * 1 ether);
        }
    }

    function test_batchClaimRewards() public {
        (bytes32 id,, bytes32[] memory list, Merkle m) = initAirdrop();

        bytes32[] memory ids = new bytes32[](6);
        for (uint8 i = 0; i < 6; i++) {
            ids[i] = id;
        }

        address[] memory users = new address[](6);
        for (uint8 i = 0; i < 6; i++) {
            users[i] = vm.addr(i + 1);
        }

        uint256[] memory amounts = new uint256[](6);
        for (uint8 i = 0; i < 6; i++) {
            amounts[i] = (1 + i) * 1 ether;
        }

        bytes32[][] memory proofs = new bytes32[][](6);
        for (uint8 i = 0; i < 6; i++) {
            proofs[i] = m.getProof(list, i);
        }

        vm.prank(defaultMaintainer);
        airdropPrograms.batchClaimRewards(ids, users, amounts, proofs);

        for (uint8 i = 0; i < 6; i++) {
            assertEq(testToken.balanceOf(vm.addr(i + 1)), (1 + i) * 1 ether);
        }
    }

    function initAirdrop() public returns (bytes32 id, bytes32 root, bytes32[] memory list, Merkle m) {
        m = new Merkle();

        id = keccak256(abi.encode("rewardProgram1"));
        uint256 totalAmount = 21 ether;
        uint128 startTimestamp = uint128(block.timestamp) - 1;
        uint128 endTimestamp = uint128(block.timestamp + 1 days);

        //create an array of elements to put in the Merkle tree
        list = new bytes32[](6);
        list[0] = encodeLeaf(id, vm.addr(1), 1 ether);
        list[1] = encodeLeaf(id, vm.addr(2), 2 ether);
        list[2] = encodeLeaf(id, vm.addr(3), 3 ether);
        list[3] = encodeLeaf(id, vm.addr(4), 4 ether);
        list[4] = encodeLeaf(id, vm.addr(5), 5 ether);
        list[5] = encodeLeaf(id, vm.addr(6), 6 ether);

        root = m.getRoot(list);

        vm.prank(defaultMaintainer);
        airdropPrograms.createAirdrop(id, address(testToken), root, totalAmount, startTimestamp, endTimestamp);
    }
}
