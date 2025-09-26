// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

/// @custom:security-contact liyuwen.lyw@antgroup.com
contract PermissionControl {
    address private administrator_;
    address[] private grantees_;

    error PermissionDenied();
    error InvalidAddress();
    error SameAddress();
    error AddressAlreadyExists();
    error AddressNotFound();

    constructor() {
        administrator_ = msg.sender;
    }

    function checkSuperPermission(address _addr) private view returns (bool) {
        if (_addr == administrator_ || _addr == address(0)) {
            return true;
        }

        return false;
    }

    function checkGrantPermission(address _addr) private view returns (bool) {
        for (uint256 i = 0; i < grantees_.length; i++) {
            if (grantees_[i] == _addr) {
                return true;
            }
        }

        return false;
    }

    event SuperTransferred(address indexed old_administrator_, address indexed new_administrator_);

    function tranferSuperAdmin(address _new_admin) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (_new_admin == address(0)) revert InvalidAddress();
        if (administrator_ == _new_admin) revert SameAddress();

        address old_admin = administrator_;
        administrator_ = _new_admin;
        emit SuperTransferred(old_admin, _new_admin);
    }

    // return administrator_
    function getSuperAdmin() external view returns (address) {
        return administrator_;
    }

    // return grantees
    function getGranteeAdmin() external view returns (address[] memory) {
        return grantees_;
    }

    event AdminGranted(address indexed grantee);

    function grantAdmin(address _addr) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (_addr == address(0)) revert InvalidAddress();
        if (checkGrantPermission(_addr)) revert AddressAlreadyExists();

        grantees_.push(_addr);
        emit AdminGranted(_addr);
    }

    event AdminRevoked(address indexed revoked);

    function revokeAdmin(address _addr) external {
        if (!checkSuperPermission(msg.sender)) revert PermissionDenied();
        if (!checkGrantPermission(_addr)) revert AddressNotFound();

        for (uint256 i = 0; i < grantees_.length; i++) {
            if (grantees_[i] == _addr) {
                grantees_[i] = grantees_[grantees_.length - 1];
                grantees_.pop();
                break;
            }
        }

        emit AdminRevoked(_addr);
    }
}
