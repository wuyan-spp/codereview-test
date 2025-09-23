// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

/// @title ITeeRollupVerifier
/// @notice The interface for TEE rollup verifier.
/// @dev This interface defines the standard for verifying TEE attestation proofs in rollup systems
interface ITeeRollupVerifier {
    /// @notice Verify TEE attestation proof from rollup
    /// @param aggrProof The aggregated proof containing TEE attestation data
    /// @return _error_code Error code (0 for success, non-zero for failure)
    /// @return commitment The extracted commitment value from the proof, used for state verification
    function verifyProof(bytes calldata aggrProof) external returns (uint32 _error_code, bytes32 commitment);
}
