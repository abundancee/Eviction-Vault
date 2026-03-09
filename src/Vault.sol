
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {VaultStorage} from "./base/VaultStorage.sol";
import {VaultTypes} from "./libraries/VaultTypes.sol";

contract EvictionVault is VaultStorage, ReentrancyGuard {

    constructor(address[] memory _owners, uint256 _threshold) payable {
        require(_owners.length > 0, "no owners");
        require(_threshold > 0, "invalid threshold");
        require(_threshold <= _owners.length, "threshold too high");
        threshold = _threshold;

        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero owner");
            require(!isOwner[o], "duplicate owner");
            isOwner[o] = true;
            owners.push(o);
        }
        totalVaultValue = msg.value;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(balances[msg.sender] >= amount, "insufficient balance");
        balances[msg.sender] -= amount;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "withdraw failed");
        totalVaultValue = address(this).balance;
        emit Withdrawal(msg.sender, amount);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner {
        uint256 id = txCount++;
        uint256 executionTime = 0;
        if (1 >= threshold) {
            executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        transactions[id] = VaultTypes.Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: executionTime
        });
        confirmed[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner {
        require(txId < txCount, "invalid tx");
        VaultTypes.Transaction storage txn = transactions[txId];
        require(!txn.executed, "already executed");
        require(!confirmed[txId][msg.sender], "already confirmed");
        confirmed[txId][msg.sender] = true;
        txn.confirmations++;
        if (txn.confirmations == threshold) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }
        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external nonReentrant {
        require(txId < txCount, "invalid tx");
        VaultTypes.Transaction storage txn = transactions[txId];
        require(txn.confirmations >= threshold, "not enough confirmations");
        require(!txn.executed, "already executed");
        require(txn.executionTime != 0, "execution time not set");
        require(block.timestamp >= txn.executionTime, "timelocked");
        txn.executed = true;
        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "execution failed");
        totalVaultValue = address(this).balance;
        emit Execution(txId);
    }

    function setMerkleRoot(bytes32 root) external onlyVault {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external whenNotPaused nonReentrant {
        require(!claimed[msg.sender], "already claimed");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        require(computed == merkleRoot, "invalid proof");
        claimed[msg.sender] = true;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "claim failed");
        totalVaultValue = address(this).balance;
        emit Claim(msg.sender, amount);
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        return ECDSA.recover(messageHash, signature) == signer;
    }

    function emergencyWithdrawAll(address payable recipient) external onlyVault {
        require(paused, "not paused");
        require(recipient != address(0), "zero recipient");
        uint256 vaultBalance = address(this).balance;
        (bool success,) = recipient.call{value: vaultBalance}("");
        require(success, "emergency withdraw failed");
        totalVaultValue = 0;
    }

    function pause() external onlyVault {
        require(!paused, "already paused");
        paused = true;
        emit Paused();
    }

    function unpause() external onlyVault {
        require(paused, "not paused");
        paused = false;
        emit Unpaused();
    }
}
