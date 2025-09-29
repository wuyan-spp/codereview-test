// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

/// @title PermissionControl
/// @author Jovay Network
/// @custom:security-contact liyuwen.lyw@antgroup.com
/// @notice This contract manages a two-tiered permission system with a super administrator and a list of general administrators (grantees).
/// @dev The super administrator has the highest level of privilege and can manage other administrators.
contract PermissionControl {
    /// @notice The address of the super administrator, who has ultimate control.
    address private administrator_;
    /// @notice A list of addresses that have been granted general admin privileges.
    address[] private grantees_;

    /// @notice Thrown when an action is attempted by an address without the required permissions.
    error PermissionDenied();
    /// @notice Thrown when a zero address is provided as an argument where it is not allowed.
    error InvalidAddress();
    /// @notice Thrown when attempting to transfer super admin role to the same address that currently holds it.
    error SameAddress();
    /// @notice Thrown when trying to grant admin privileges to an address that already has them.
    error AddressAlreadyExists();
    /// @notice Thrown when trying to revoke admin privileges from an address that does not have them.
    error AddressNotFound();

    /// @notice Emitted when the super administrator role is transferred to a new address.
    /// @param old_administrator_ The address of the previous super administrator.
    /// @param new_administrator_ The address of the new super administrator.
    event SuperTransferred(address indexed old_administrator_, address indexed new_administrator_);

    /// @notice Emitted when admin privileges are granted to an address.
    /// @param grantee The address that was granted admin privileges.
    event AdminGranted(address indexed grantee);

    /// @notice Emitted when admin privileges are revoked from an address.
    /// @param revoked The address whose admin privileges were revoked.
    event AdminRevoked(address indexed revoked);

    /// @notice Sets the contract deployer as the initial super administrator.
    constructor() {
        administrator_ = msg.sender;
    }

    /// @notice Transfers the super administrator role to a new address.
    /// @dev Can only be called by the current super administrator. The new admin cannot be the zero address or the same as the current admin.
    /// @param _new_admin The address of the new super administrator.
    function tranferSuperAdmin(address _new_admin) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (_new_admin == address(0)) revert InvalidAddress();
        if (administrator_ == _new_admin) revert SameAddress();

        address old_admin = administrator_;
        administrator_ = _new_admin;
        emit SuperTransferred(old_admin, _new_admin);
    }

    /// @notice Grants admin privileges to an address.
    /// @dev Can only be called by the super administrator. The grantee cannot be the zero address and cannot already be an admin.
    /// @param _addr The address to be granted admin privileges.
    function grantAdmin(address _addr) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (_addr == address(0)) revert InvalidAddress();
        if (checkGrantPermission(_addr)) revert AddressAlreadyExists();

        grantees_.push(_addr);
        emit AdminGranted(_addr);
    }

    /// @notice Revokes admin privileges from an address.
    /// @dev Can only be called by the super administrator. The address must currently have admin privileges.
    /// This function uses the "swap and pop" method for efficient removal from the array.
    /// @param _addr The address from which to revoke admin privileges.
    function revokeAdmin(address _addr) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (!checkGrantPermission(_addr)) revert AddressNotFound();

        for (uint256 i = 0; i < grantees_.length; i++) {
            if (grantees_[i] == _addr) {
                // Replace the found address with the last element in the array
                grantees_[i] = grantees_[grantees_.length - 1];
                // Remove the last element
                grantees_.pop();
                break;
            }
        }

        emit AdminRevoked(_addr);
    }

    /// @notice Gets the address of the current super administrator.
    /// @return The address of the super administrator.
    function getSuperAdmin() external view returns (address) {
        return administrator_;
    }

    /// @notice Gets the list of all addresses with granted admin privileges.
    /// @return An array of grantee addresses.
    function getGranteeAdmin() external view returns (address[] memory) {
        return grantees_;
    }

    /// @notice Checks if an address has super administrator permissions.
    /// @dev Only the designated administrator_ address has super permissions.
    /// @param _addr The address to check.
    /// @return bool True if the address is the super administrator, false otherwise.
    function checkSuperPermission(address _addr) private view returns (bool) {
        return _addr == administrator_;
    }

    /// @notice Checks if an address has been granted admin privileges.
    /// @dev Iterates through the grantees_ array to find a match.
    /// @param _addr The address to check.
    /// @return bool True if the address is a grantee, false otherwise.
    function checkGrantPermission(address _addr) private view returns (bool) {
        for (uint256 i = 0; i < grantees_.length; i++) {
            if (grantees_[i] == _addr) {
                return true;
            }
        }

        return false;
    }
}
