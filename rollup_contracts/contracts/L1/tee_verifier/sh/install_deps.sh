#!/bin/bash
set -e # Exit on error

# Navigate to the project root (tee_verifier)
cd "$(dirname "$0")/.."

# Install dependencies
forge install --no-commit vectorized/solady@v0.1.24
forge install --no-commit foundry-rs/forge-std
forge install --no-commit automata-network/automata-dcap-attestation@evm-v1.0.0

cd sh
cp patch/0001-support-v5-quote.patch ../lib/automata-dcap-attestation
cp patch/0001-bugfix-collaterals-expiration-check.patch ../lib/automata-dcap-attestation
cd ../lib/automata-dcap-attestation
git apply 0001-support-v5-quote.patch
git apply 0001-bugfix-collaterals-expiration-check.patch
