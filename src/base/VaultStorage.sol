// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VaultTypes} from "../libraries/VaultTypes.sol";

abstract contract VaultStorage {
    uint256 public constant TIMELOCK_DURATION = 1 hours;

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => VaultTypes.Transaction) public transactions;
    uint256 public txCount;

    mapping(address => uint256) public balances;
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    uint256 public totalVaultValue;
    bool public paused;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);
    event Paused();
    event Unpaused();

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    function _onlyOwner() internal view {
        require(isOwner[msg.sender], "not owner");
    }

    function _onlyVault() internal view {
        require(msg.sender == address(this), "only vault");
    }

    function _whenNotPaused() internal view {
        require(!paused, "paused");
    }
}
