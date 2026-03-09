// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EvictionVault} from "../src/Vault.sol";

contract EvictionVaultTest is Test {
    EvictionVault public vault;
    address public ownerTwo;
    address public user;
    address public emergencyRecipient;

    uint256 internal constant TIMELOCK_DURATION = 1 hours;

    function setUp() public {
        ownerTwo = makeAddr("ownerTwo");
        user = makeAddr("user");
        emergencyRecipient = makeAddr("emergencyRecipient");

        address[] memory owners = new address[](2);
        owners[0] = address(this);
        owners[1] = ownerTwo;

        vault = new EvictionVault{value: 10 ether}(owners, 2);

        vm.deal(user, 2 ether);
    }

    function test_DepositAndWithdrawFlow() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}();

        assertEq(vault.balances(user), 1 ether);

        uint256 userBalanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw(0.4 ether);

        assertEq(vault.balances(user), 0.6 ether);
        assertEq(user.balance, userBalanceBefore + 0.4 ether);
    }

    function test_SetMerkleRootOnlyViaGovernance() public {
        bytes32 newRoot = keccak256("root");

        vm.expectRevert("only vault");
        vault.setMerkleRoot(newRoot);

        _executeGovernanceCall(address(vault), 0, abi.encodeCall(EvictionVault.setMerkleRoot, (newRoot)));

        assertEq(vault.merkleRoot(), newRoot);
    }

    function test_TimelockBlocksEarlyExecution() public {
        uint256 txId = vault.txCount();
        vault.submitTransaction(address(vault), 0, abi.encodeCall(EvictionVault.pause, ()));

        vm.prank(ownerTwo);
        vault.confirmTransaction(txId);

        vm.expectRevert("timelocked");
        vault.executeTransaction(txId);

        vm.warp(block.timestamp + TIMELOCK_DURATION);
        vault.executeTransaction(txId);

        assertTrue(vault.paused());
    }

    function test_PauseAndUnpauseRequireGovernance() public {
        vm.expectRevert("only vault");
        vault.pause();

        _executeGovernanceCall(address(vault), 0, abi.encodeCall(EvictionVault.pause, ()));
        assertTrue(vault.paused());

        _executeGovernanceCall(address(vault), 0, abi.encodeCall(EvictionVault.unpause, ()));
        assertFalse(vault.paused());
    }

    function test_EmergencyWithdrawAllRequiresGovernanceAndPaused() public {
        vm.expectRevert("only vault");
        vault.emergencyWithdrawAll(payable(emergencyRecipient));

        _executeGovernanceCall(address(vault), 0, abi.encodeCall(EvictionVault.pause, ()));

        uint256 vaultBalance = address(vault).balance;
        _executeGovernanceCall(
            address(vault),
            0,
            abi.encodeCall(EvictionVault.emergencyWithdrawAll, (payable(emergencyRecipient)))
        );

        assertEq(address(vault).balance, 0);
        assertEq(emergencyRecipient.balance, vaultBalance);
    }

    function test_ClaimUsesMerkleProofAndTransfersFunds() public {
        uint256 amount = 0.5 ether;
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));

        _executeGovernanceCall(address(vault), 0, abi.encodeCall(EvictionVault.setMerkleRoot, (leaf)));

        uint256 userBalanceBefore = user.balance;
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(user);
        vault.claim(proof, amount);

        assertEq(user.balance, userBalanceBefore + amount);
        assertTrue(vault.claimed(user));
    }

    function _executeGovernanceCall(address to, uint256 value, bytes memory data) internal {
        uint256 txId = vault.txCount();
        vault.submitTransaction(to, value, data);

        vm.prank(ownerTwo);
        vault.confirmTransaction(txId);

        vm.warp(block.timestamp + TIMELOCK_DURATION);
        vault.executeTransaction(txId);
    }
}
