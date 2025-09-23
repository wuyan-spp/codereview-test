pragma solidity 0.8.27;

import {Ownable} from "solady/auth/Ownable.sol";
import {ITeeRollupVerifier} from "./interfaces/ITeeRollupVerifier.sol";
import {DcapAttestationRouter} from "./DcapAttestationRouter.sol";

/**
 * @title TEEVerifierProxy
 * @notice Proxy contract for TEE attestation verification that delegates to DcapAttestationRouter
 * @dev This contract acts as a proxy interface for verifying TEE attestation proofs
 */
contract TEEVerifierProxy is ITeeRollupVerifier, Ownable {
    /// @notice Address of the DcapAttestationRouter contract
    address public dcapAttestationRouter;
    
    /// @notice Mapping of authorized callers
    mapping(address => bool) private _authorized;
    
    /// @notice Flag indicating whether caller restriction is enabled
    bool private _isCallerRestricted = true;

    error Forbidden();
    error InvalidAddress();

    modifier onlyAuthorized() {
        if (_isCallerRestricted && !_authorized[msg.sender]) {
            revert Forbidden();
        }
        _;
    }

    /**
     * @notice Constructor to initialize the proxy with DcapAttestationRouter address
     * @param _dcapAttestationRouter Address of the DcapAttestationRouter contract
     */
    constructor(address _dcapAttestationRouter) {
        if (_dcapAttestationRouter == address(0)) revert InvalidAddress();
        _initializeOwner(msg.sender);
        _setConfig(_dcapAttestationRouter);
        _authorized[msg.sender] = true;
    }

    /**
     * @notice Set the DcapAttestationRouter contract address
     * @param _dcapAttestationRouter Address of the DcapAttestationRouter contract
     */
    function setConfig(address _dcapAttestationRouter) external onlyOwner {
        if (_dcapAttestationRouter == address(0)) revert InvalidAddress();
        _setConfig(_dcapAttestationRouter);
    }

    /**
     * @notice Set authorization status for a caller
     * @param caller Address to set authorization for
     * @param authorized Whether the caller is authorized
     */
    function setAuthorized(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert InvalidAddress();
        _authorized[caller] = authorized;
    }

    /**
     * @notice Enable caller restriction (only authorized callers can call functions)
     */
    function enableCallerRestriction() external onlyOwner {
        _isCallerRestricted = true;
    }

    function disableCallerRestriction() external onlyOwner {
        _isCallerRestricted = false;
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
    }
}
