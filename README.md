# Eviction Vault

Refactored from a single-file contract into a modular structure with immediate security hardening.

## Current Structure

- `src/Vault.sol`: main contract logic
- `src/base/VaultStorage.sol`: shared storage, events, and modifiers
- `src/libraries/VaultTypes.sol`: reusable struct definitions

## Critical Fixes Implemented

- `setMerkleRoot` is no longer publicly callable.

	-- It is now governance-only (`onlyVault`) and must be executed through threshold confirmations and timelock.
- `emergencyWithdrawAll` public drain removed.
	
	-- It is governance-only, requires paused state, and requires a non-zero recipient.
- `pause/unpause` single-owner control removed.
	
	-- Both actions are governance-only (`onlyVault`) through multisig + timelock execution.
- `receive()` no longer uses `tx.origin`.
	
	-- Deposits now credit `msg.sender`.
- `withdraw` and `claim` no longer use `.transfer`.
	
	-- Both use safe low-level `.call` and are protected with `ReentrancyGuard`.
- Timelock execution strengthened.
	
	-- `executionTime` is correctly set when threshold is reached, including threshold-on-submit cases.
	
	-- Execution requires non-zero `executionTime` and enforces delay.

## Test Coverage

Implemented 6 basic tests in `test/Vault.t.sol`:

- Deposit and withdraw flow
- Merkle root updates through governance only
- Timelock blocking early execution
- Pause/unpause through governance only
- Emergency withdraw restricted to governance in paused state
- Merkle claim payout flow

## Commands

```bash
forge build
forge test
```

