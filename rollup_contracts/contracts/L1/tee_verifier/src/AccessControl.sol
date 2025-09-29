// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title AccessControl
 * @notice A reusable access control contract that provides role-based authorization
 * @dev This contract can be inherited by other contracts to avoid duplicating access control logic
 */
contract AccessControl is Ownable {
    /// @notice Event emitted when authorization status is changed
    event AuthorizationSet(address indexed caller, bool authorized);

    /// @notice Event emitted when caller restriction is enabled
    event CallerRestrictionEnabled();

    /// @notice Event emitted when caller restriction is disabled
    event CallerRestrictionDisabled();

    /// @notice Mapping of authorized callers
    mapping(address => bool) private _authorized;

    /// @notice Flag indicating whether caller restriction is enabled
    bool private _isCallerRestricted = true;

    error Forbidden();
    error InvalidAddress();

    /**
     * @notice Modifier that restricts function access to authorized callers
     */
    modifier onlyAuthorized() {
        if (_isCallerRestricted && !_authorized[msg.sender]) {
            revert Forbidden();
        }
        _;
    }

    /**
     * @notice Constructor that authorizes the deployer
     */
    constructor() {
        _authorized[msg.sender] = true;
    }

    /**
     * @notice Set authorization status for a caller
     * @param caller Address to set authorization for
     * @param authorized Whether the caller is authorized
     */
    function setAuthorized(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert InvalidAddress();
        _authorized[caller] = authorized;
        emit AuthorizationSet(caller, authorized);
    }

    /**
     * @notice Enable caller restriction (only authorized callers can call functions)
     */
    function enableCallerRestriction() external onlyOwner {
        _isCallerRestricted = true;
        emit CallerRestrictionEnabled();
    }

    /**
     * @notice Disable caller restriction (anyone can call functions)
     */
    function disableCallerRestriction() external onlyOwner {
        _isCallerRestricted = false;
        emit CallerRestrictionDisabled();
    }

    /**
     * @notice Check if an address is authorized
     * @param caller Address to check
     * @return True if the address is authorized, false otherwise
     */
    function isAuthorized(address caller) external view returns (bool) {
        return _authorized[caller];
    }

    /**
     * @notice Check if caller restriction is enabled
     * @return True if caller restriction is enabled, false otherwise
     */
    function isCallerRestricted() external view returns (bool) {
        return _isCallerRestricted;
    }
}
