// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IAirdropPrograms } from "./interfaces/IAirdropPrograms.sol";

import { AccessControlUpgradeable } from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "openzeppelin-contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ReentrancyGuardUpgradeable } from "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { MerkleProof } from "openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { ErrorsLib } from "./libraries/ErrorsLib.sol";
import { EventsLib } from "./libraries/EventsLib.sol";

contract AirdropPrograms is
    IAirdropPrograms,
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using MerkleProof for bytes32[];

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    struct Airdrop {
        address token;
        bytes32 root;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint128 startTimestamp;
        uint128 endTimestamp;
        bool isActive;
    }

    mapping(bytes32 => Airdrop) public airdrops;
    mapping(bytes32 => mapping(address => bool)) public isClaimed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _maintainer) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        if (_admin == address(0) || _maintainer == address(0)) {
            revert ErrorsLib.InvalidAdminOrMaintainer();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(MAINTAINER_ROLE, _maintainer);
    }

    function claimRewards(
        bytes32 id,
        address user,
        uint256 amount,
        bytes32[] calldata proof
    )
        public
        nonReentrant
        whenNotPaused
    {
        if (!airdrops[id].isActive) {
            revert ErrorsLib.AirdropIsNotActive(id);
        }

        if (isClaimed[id][user]) {
            revert ErrorsLib.AirdropAlreadyClaimed(id);
        }

        Airdrop storage airdrop = airdrops[id];

        if (amount == 0 || amount > airdrop.totalAmount) {
            revert ErrorsLib.InvalidAirdropAmount();
        }

        if (airdrop.startTimestamp > block.timestamp || airdrop.endTimestamp < block.timestamp) {
            revert ErrorsLib.AirdropIsNotActive(id);
        }

        if (!proof.verify(airdrop.root, _leaf(id, user, amount))) {
            revert ErrorsLib.InvalidProof();
        }

        isClaimed[id][user] = true;
        airdrop.claimedAmount += amount;

        IERC20(airdrop.token).safeTransfer(user, amount);

        emit EventsLib.AirdropClaimed(id, user, airdrop.token, amount);
    }

    function batchClaimRewards(
        bytes32[] calldata ids,
        address[] calldata users,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    )
        public
        whenNotPaused
    {
        for (uint256 i = 0; i < ids.length; i++) {
            claimRewards(ids[i], users[i], amounts[i], proofs[i]);
        }
    }

    function createAirdrop(
        bytes32 id,
        address token,
        bytes32 root,
        uint256 totalAmount,
        uint128 startTimestamp,
        uint128 endTimestamp
    )
        public
        onlyRole(MAINTAINER_ROLE)
    {
        if (airdrops[id].token != address(0)) {
            revert ErrorsLib.AirdropAlreadyExists(id);
        }

        if (token == address(0) || totalAmount == 0 || root == bytes32(0)) {
            revert ErrorsLib.InvalidAirdropParameters();
        }

        airdrops[id] = Airdrop({
            token: token,
            root: root,
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            isActive: true
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);

        emit EventsLib.AirdropCreated(id, token, root, totalAmount, startTimestamp, endTimestamp);
    }

    function updateAirdrop(
        bytes32 id,
        address token,
        bytes32 root,
        uint256 totalAmount,
        uint128 startTimestamp,
        uint128 endTimestamp
    )
        public
        onlyRole(MAINTAINER_ROLE)
    {
        if (airdrops[id].token == address(0)) {
            revert ErrorsLib.AirdropDoesNotExist(id);
        }

        if (token == address(0) || totalAmount == 0 || root == bytes32(0)) {
            revert ErrorsLib.InvalidAirdropParameters();
        }

        Airdrop memory preAirdrop = airdrops[id];

        airdrops[id] = Airdrop({
            token: token,
            root: root,
            totalAmount: totalAmount,
            claimedAmount: preAirdrop.claimedAmount,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            isActive: preAirdrop.isActive
        });

        if (preAirdrop.totalAmount < totalAmount) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount - preAirdrop.totalAmount);
        } else {
            IERC20(token).safeTransfer(msg.sender, preAirdrop.totalAmount - totalAmount);
        }

        emit EventsLib.AirdropUpdated(id, token, root, totalAmount, startTimestamp, endTimestamp);
    }

    function disperseToken(
        IERC20 token,
        address[] calldata recipients,
        uint256[] calldata values
    )
        external
        onlyRole(MAINTAINER_ROLE)
    {
        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            total += values[i];
        }
        token.safeTransferFrom(msg.sender, address(this), total);
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
        }
    }

    function pauseAirdropById(bytes32 id) public onlyRole(MAINTAINER_ROLE) {
        if (airdrops[id].token == address(0)) {
            revert ErrorsLib.AirdropDoesNotExist(id);
        }

        airdrops[id].isActive = false;

        emit EventsLib.AirdropPaused(id);
    }

    function pause() public onlyRole(MAINTAINER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(MAINTAINER_ROLE) {
        _unpause();
    }

    function getAirdrop(bytes32 id) public view returns (Airdrop memory) {
        return airdrops[id];
    }

    function checkProof(
        bytes32 id,
        address user,
        uint256 amount,
        bytes32[] calldata proof
    )
        public
        view
        returns (bool)
    {
        return proof.verify(airdrops[id].root, _leaf(id, user, amount));
    }

    function isUserClaimed(address user, bytes32[] calldata ids) public view returns (bool[] memory) {
        bool[] memory claimed = new bool[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            claimed[i] = isClaimed[ids[i]][user];
        }
        return claimed;
    }

    function _leaf(bytes32 id, address user, uint256 amount) internal pure returns (bytes32) {
        return keccak256(abi.encode(id, user, amount));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
