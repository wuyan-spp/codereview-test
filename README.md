# Jovay Contracts

This repository contains the smart contracts for the Jovay Network, a Layer 2 scaling solution.

## Overview

Jovay Contracts implements the core infrastructure for L1/L2 communication, including:

- **Rollup System**: Batch submission and verification of L2 transactions on L1
- **Cross-chain Bridge**: Asset transfers between L1 and L2 (ETH and ERC20 tokens)
- **Proof Verification**: Supports multiple verifiers including TEE (Trusted Execution Environment) and ZK (Zero-Knowledge) proofs

## Architecture

```
contracts/src/
├── common/              # Shared base contracts
├── L1/                  # Layer 1 contracts (deployed on Ethereum)
│   ├── bridge/          # L1 bridge contracts (ETH, ERC20)
│   ├── core/            # Rollup and L1 Mailbox
│   ├── libraries/       # Codec and verifier utilities
│   └── tee_verifier/    # TEE attestation verification
└── L2/                  # Layer 2 contracts (deployed on Jovay)
    ├── bridge/          # L2 bridge contracts
    ├── core/            # L2 Mailbox, Gas Oracle, CoinBase
    ├── msgOracle/       # Message oracle for cross-chain communication
    ├── rule/            # Limitation rules
    └── sys/             # System contracts (ChainCfg, etc.)
```

### L1 Contracts

| Contract | Description |
|----------|-------------|
| `Rollup.sol` | Handles batch commitment and verification |
| `L1Mailbox.sol` | Manages L1→L2 message queue |
| `L1ETHBridge.sol` | ETH deposit from L1 to L2 |
| `L1ERC20Bridge.sol` | ERC20 token deposit from L1 to L2 |

### L2 Contracts

| Contract | Description |
|----------|-------------|
| `L2Mailbox.sol` | Manages L2→L1 message queue |
| `L2ETHBridge.sol` | ETH withdrawal from L2 to L1 |
| `L2ERC20Bridge.sol` | ERC20 token withdrawal from L2 to L1 |
| `L1GasOracle.sol` | L1 gas price oracle for fee estimation |
| `ChainCfg.sol` | Chain configuration management |
| `DPoSValidatorManager.sol` | Validator epoch management |

## Compilation

This project uses [Foundry](https://getfoundry.sh/) for smart contract compilation.

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Git](https://git-scm.com/) (for installing `tee_verifier` dependencies)

### Instructions

A convenience script is provided to compile all contracts in the repository.

1.  **Make sure the script is executable:**
    ```bash
    chmod +x compile.sh
    ```

2.  **Run the compilation script:**
    ```bash
    ./compile.sh
    ```

This will compile the `contracts`, the nested `tee_verifier` contract, and the `sequencer_contracts`.

### Artifacts Location

-   **Rollup Contracts:** The compiled artifacts will be located in the `contracts/out/` directory.
-   **TEE Verifier Contract:** The compiled artifacts will be located in the `contracts/src/L1/tee_verifier/out/` directory.
-   **Sequencer Contracts:** The compiled artifacts will be located in the `contracts/src/L2/sys/out/` directory. The output for each contract (e.g., `erc_20.sol`) will be a JSON file (`erc_20.json`) containing the ABI, bytecode, and other metadata.

## Testing

Run the test suite using Foundry:

```bash
cd contracts
forge test
```

## Documentation

For detailed design documentation, see:

- [Bridge Contract Design](docs/simple_design/contracts/bridge_contract_design.md)
- [TEE Verifier Design](docs/simple_design/contracts/tee_verifier_design.md)

## Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Forge Std](https://github.com/foundry-rs/forge-std)
- [Automata DCAP Attestation](https://github.com/automata-network/automata-dcap-attestation) (for TEE verification)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
