#!/bin/bash
set -e # Exit on error

# Navigate to the project root (tee_verifier)
cd "$(dirname "$0")/.."

# Clean up existing lib directory to avoid conflicts
rm -rf lib
mkdir -p lib

# Install dependencies using git clone to avoid forge install issues
echo "Installing solady..."
git clone --depth 1 --branch v0.1.24 https://github.com/vectorized/solady.git lib/solady

echo "Installing forge-std..."
git clone --depth 1 https://github.com/foundry-rs/forge-std.git lib/forge-std

echo "Installing automata-dcap-attestation..."
git clone --depth 1 --branch v1.0.0 https://github.com/automata-network/automata-dcap-attestation.git lib/automata-dcap-attestation

# Initialize submodules for automata-dcap-attestation
echo "Initializing automata-dcap-attestation submodules..."
cd lib/automata-dcap-attestation
git submodule update --init --recursive

# Apply patches
echo "Applying patches..."
git apply ../../sh/patch/0001-support-v5-quote.patch
git apply ../../sh/patch/0001-bugfix-collaterals-expiration-check.patch

echo "Dependencies installed successfully!"
