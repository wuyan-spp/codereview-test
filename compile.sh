#!/bin/bash
set -e

echo "Installing dependencies for rcontracts..."
(cd contracts && npm install)

echo "Compiling contracts..."
(cd contracts && forge build)

echo "Setting up tee_verifier dependencies..."
(
  cd contracts/src/L1/tee_verifier/sh
  chmod +x ./install_deps.sh
  ./install_deps.sh
)

echo "Compiling tee_verifier..."
(cd contracts/src/L1/tee_verifier && forge build)

echo "Compilation complete."
