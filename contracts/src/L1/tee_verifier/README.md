## About automata-dcap-attestation dependency
The contracts in the tee_verifier directory use the [automata-dcap-attestation](https://github.com/automata-network/automata-dcap-attestation/releases/tag/v1.0.0) dependency. Two modifications have been made on top of the base library:

- Added support for quote v5 verification.
- Fixed a bug in the `PCCSRouter` contract.

## automata-dcap-attestation installation steps
- Navigate to the tee_verifier/sh directory and run `bash install_deps.sh`.
- Change to the tee_verifier/lib/automata-dcap-attestation directory.
- Review the modifications in the patch file.