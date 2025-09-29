// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

/// @title ITeeRollupVerifier
/// @notice The interface for TEE rollup verifier.
interface ITeeRollupVerifier {
    /// @notice Verify TEE proof.
    /// @param aggrProof The aggregated proof.
    function verifyProof(bytes calldata aggrProof) external returns (uint32 _error_code, bytes32 commitment);
}
