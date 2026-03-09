// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library VaultTypes {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }
}
