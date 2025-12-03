# Jovay Contracts

This repository contains the smart contracts for the Jovay Network.

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
