#!/bin/bash
set -e

echo "Installing dependencies for rollup_contracts..."
(cd rollup_contracts && npm install)

echo "Compiling rollup_contracts..."
(cd rollup_contracts && forge build)

echo "Setting up tee_verifier dependencies..."
(
  cd rollup_contracts/contracts/L1/tee_verifier/sh
  chmod +x ./install_deps.sh
  ./install_deps.sh
)

echo "Compiling tee_verifier..."
(cd rollup_contracts/contracts/L1/tee_verifier && forge build)

echo "Compiling sequencer_contracts..."
(cd sequencer_contracts/sys_contract && forge build)

echo "Compilation complete."
