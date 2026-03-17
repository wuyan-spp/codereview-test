# Jovay Contracts — Project Guide for Claude

## Project Overview

Jovay is a Layer 2 Rollup network built on Ethereum. This repository contains
the core smart contracts for L1/L2 communication, including:

- **Rollup**: Batch commitment and verification (TEE + ZK dual-proof system)
- **Bridge**: ETH and ERC20 cross-chain asset transfers (L1 ↔ L2)
- **Mailbox**: Cross-chain message queue (L1Mailbox, L2Mailbox)
- **TEE Verifier**: On-chain Intel DCAP attestation verification stack

## Code Standards

### Solidity
- All production contracts use `pragma solidity 0.8.30;` (fixed version, not a range)
- TEE verifier sub-module uses `pragma solidity 0.8.27;`
- License: `// SPDX-License-Identifier: MIT` (space after `//` is required)
- File structure order: `SPDX comment → pragma → imports → contract`
- Follow Checks-Effects-Interactions (CEI) pattern for all state-changing functions
- Use `nonReentrant` on every external function that transfers ETH or ERC20 tokens

### Naming & Style
- Contract variables: `camelCase` with trailing `_` for parameters (e.g., `amount_`, `to_`)
- Constants: `UPPER_SNAKE_CASE`
- Events: `PascalCase`, emitted **after** state changes
- Custom errors preferred over `require` strings for gas efficiency in new code
- NatSpec `@notice` and `@param` required for all `external` / `public` functions

### Security Invariants
- Every `external payable` function must validate `msg.value` matches the intended
  transfer amount — never rely solely on a separate `amount_` parameter
- Zero-address checks required for all address parameters in initializers and setters
- `onlyOwner` / `onlyRelayer` / `onlyBridge` access guards must be applied correctly
- State changes must precede external calls (CEI); document any intentional deviation
- `_disableInitializers()` required in every upgradeable contract constructor
- Critical parameter updates (verifier address, mailbox address) require `whenPaused`

### Upgradeable Contracts
- Inherit from OpenZeppelin Upgradeable variants (`OwnableUpgradeable`, etc.)
- Never call `__Ownable_init()` when ownership is already transferred elsewhere in init
- Maintain `uint256[50] private __gap;` at the end of every base contract storage layout

## Directory Structure

```
contracts/src/
├── common/          # Shared base contracts (BridgeBase, MailBoxBase, TokenBridge)
├── L1/              # Ethereum mainnet contracts
│   ├── bridge/      # L1ETHBridge, L1ERC20Bridge, L1BridgeProof
│   ├── core/        # Rollup, L1Mailbox
│   ├── libraries/   # BatchHeaderCodec, verifier interfaces
│   └── tee_verifier/# DCAP attestation stack (separate Foundry sub-project)
└── L2/              # Jovay L2 contracts
    ├── bridge/      # L2ETHBridge, L2ERC20Bridge
    ├── core/        # L2Mailbox, L1GasOracle, L2CoinBase
    ├── rule/        # L2WithdrawLimitation, L2RuleManager
    └── sys/         # ChainCfg, DPoSValidatorManager
```

## Testing

```bash
cd contracts && forge test          # run all tests
cd contracts && forge build         # compile
```

The `tee_verifier` sub-module has its own Foundry project under
`contracts/src/L1/tee_verifier/`. Its tests require a private key and cannot
run in CI without credentials — they are intentionally excluded from CI.

## Dependencies

- OpenZeppelin Contracts Upgradeable v4.x
- Foundry (forge) for compilation and testing
- Automata DCAP Attestation library (TEE verifier only)
