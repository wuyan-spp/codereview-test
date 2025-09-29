// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {AccessControl} from "./AccessControl.sol";
import {ITeeRollupVerifier} from "./interfaces/ITeeRollupVerifier.sol";
import {DcapAttestationRouter} from "./DcapAttestationRouter.sol";

/**
 * @title TEEVerifierForwarder
 * @notice Forwarder contract for TEE attestation verification that forwards to DcapAttestationRouter
 * @dev This contract acts as a forwarder interface for verifying TEE attestation proofs
 * @custom:security-contact mintian.hym@antgroup.com
 */
contract TEEVerifierForwarder is ITeeRollupVerifier, AccessControl {
    /// @notice Address of the DcapAttestationRouter contract
    address public dcapAttestationRouter;

    /// @notice Event emitted when configuration is updated
    event ConfigUpdated(address indexed dcapAttestationRouter);

    /**
     * @notice Constructor to initialize the proxy with DcapAttestationRouter address
     * @param _dcapAttestationRouter Address of the DcapAttestationRouter contract
     */
    constructor(address _dcapAttestationRouter) {
        require(_dcapAttestationRouter != address(0), InvalidAddress());
        _initializeOwner(msg.sender);
        _setConfig(_dcapAttestationRouter);
    }

    /**
     * @notice Set the DcapAttestationRouter contract address
     * @param _dcapAttestationRouter Address of the DcapAttestationRouter contract
     */
    function setConfig(address _dcapAttestationRouter) external onlyOwner {
        require(_dcapAttestationRouter != address(0), InvalidAddress());
        _setConfig(_dcapAttestationRouter);
    }

    /**
     * @notice Verify proof from rollup
     * @param aggrProof The aggregated proof containing the TEE quote
     * @return _error_code Error code (0 for success, 1 for failure)
     * @return commitment The extracted commitment from the quote
     */
    function verifyProof(bytes calldata aggrProof)
        external
        onlyAuthorized
        returns (uint32 _error_code, bytes32 commitment)
    {
        DcapAttestationRouter router = DcapAttestationRouter(dcapAttestationRouter);
        (_error_code, commitment) = router.verifyProof(aggrProof);
    }

    /**
     * @notice Internal function to set the DcapAttestationRouter address
     * @param _dcapAttestationRouter Address of the DcapAttestationRouter contract
     */
    function _setConfig(address _dcapAttestationRouter) private {
        dcapAttestationRouter = _dcapAttestationRouter;
        emit ConfigUpdated(_dcapAttestationRouter);
    }
}
