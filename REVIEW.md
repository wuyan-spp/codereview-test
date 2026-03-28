# Code Review Guide for Jovay Contracts

This file provides instructions for Claude Code Review when analyzing pull
requests in this repository.

## Priority Checks

### 🔴 Always flag (blocking)

1. **msg.value / amount mismatch**
   Any `payable` function that accepts both `msg.value` and a separate `amount_`
   parameter must have `require(msg.value == amount_, ...)` or equivalent.
   Missing this check allows callers to send mismatched ETH, causing fund loss.

2. **CEI violations**
   External calls (`.call`, `.transfer`, token transfers) must come *after* all
   state changes. Flag any pattern where state is mutated after an external call.

3. **Reentrancy without guard**
   Any `external` function that calls out to unknown addresses and lacks
   `nonReentrant` must be flagged.

4. **Missing zero-address validation**
   `address(0)` checks are required in all `initialize()` functions and any
   setter that updates a critical address (mailbox, bridge, verifier, owner).

5. **Access control gaps**
   Verify that privilege-restricted operations (`onlyOwner`, `onlyRelayer`,
   `onlyBridge`, `onlyRollup`) are applied correctly. Pay special attention to
   functions that move funds or change core configuration.

6. **SPDX / pragma format**
   - License comment must be `// SPDX-License-Identifier: MIT` (space after `//`)
   - `pragma solidity` must appear *before* all `import` statements

### 🟡 Flag as nit (non-blocking)

- Use of deprecated `.transfer()` — prefer `.call{value: ...}("")` with return-value check
- Missing `emit` for significant state changes
- `require` with long string message — prefer custom errors for gas efficiency
- Unbounded loops over storage arrays (flag if array can grow without limit)
- Magic numbers without named constants

## What to Skip

- `contracts/src/L1/tee_verifier/test/` — TEE verifier test utilities
- `contracts/src/L1/tee_verifier/script/` — deployment and upsert scripts
- `contracts/src/L1/tee_verifier/sh/patch/` — upstream library patches
- Generated files or files under `out/` directories
- `*.t.sol` test files in `contracts/test/`

## Solidity-Specific Guidance

- This project targets **Solidity 0.8.30**; arithmetic overflow is checked by default,
  but flag `unchecked` blocks that lack clear justification
- Upgradeable contracts must keep their `__gap` storage padding — flag if removed
- The `_disableInitializers()` pattern must be present in every upgradeable constructor
- `whenPaused` is the intended gate for critical address updates; flag if missing

## Context Notes

- The Rollup contract intentionally reverts on ZK proof (`NotSupportZkProof`);
  this is expected during the current TEE-first phase — do not flag as a bug
- `DPoSValidatorManager` uses an older bool-based reentrancy guard by design
  for L2 system contract compatibility; do not flag the lock style
- `L2Mailbox.version` and `MsgOracle` introduce an optional message approval
  layer; the dual-path logic (`version < ORACLE_VERSION`) is intentional
