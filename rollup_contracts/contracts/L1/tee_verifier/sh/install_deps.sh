#!/bin/bash

cd ..

forge install vectorized/solady
forge install foundry-rs/forge-std
forge install automata-network/automata-dcap-attestation@evm-v1.0.0

cd sh
cp patch/0001-support-v5-quote.patch ../lib/automata-dcap-attestation
cp patch/0001-bugfix-collaterals-expiration-check.patch ../lib/automata-dcap-attestation
cd ../lib/automata-dcap-attestation
git apply 0001-support-v5-quote.patch
git apply 0001-bugfix-collaterals-expiration-check.patch 