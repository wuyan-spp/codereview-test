// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../artifact_src/solidity/permission_control.sol";
contract PermissionControlTest is Test {
    PermissionControl public permissionControl;
    address public owner;
    address public grantee1;
    address public grantee2;

    error PermissionDenied();
    error InvalidAddress();
    error SameAddress();
    error AddressAlreadyExists();
    error AddressNotFound();

    function setUp() public {
        permissionControl = new PermissionControl();
        owner = address(this);
        grantee1 = address(0x1234);
        grantee2 = address(0x5678);
    }
    function test_initialState() public view {
        assertEq(permissionControl.getSuperAdmin(), owner);
        assertEq(permissionControl.getGranteeAdmin().length, 0);
    }
    function test_grantAdminAsOwner() public {
        permissionControl.grantAdmin(grantee1);
        
        address[] memory grantees = permissionControl.getGranteeAdmin();
        assertEq(grantees.length, 1);
        assertEq(grantees[0], grantee1);
    }
    function test_grantAdminAsNonOwner() public {
        vm.prank(grantee1);
        vm.expectRevert(abi.encodeWithSelector(PermissionDenied.selector));
        permissionControl.grantAdmin(grantee2);
    }
    function test_grantAdminDuplicate() public {
        permissionControl.grantAdmin(grantee1);
        
        vm.expectRevert(abi.encodeWithSelector(AddressAlreadyExists.selector));
        permissionControl.grantAdmin(grantee1);
    }
    function test_revokeAdminAsOwner() public {
        permissionControl.grantAdmin(grantee1);
        permissionControl.revokeAdmin(grantee1);
        
        address[] memory grantees = permissionControl.getGranteeAdmin();
        assertEq(grantees.length, 0);
    }
    function test_revokeAdminAsNonOwner() public {
        permissionControl.grantAdmin(grantee1);
        
        vm.prank(grantee1);
        vm.expectRevert(abi.encodeWithSelector(PermissionDenied.selector));
        permissionControl.revokeAdmin(grantee1);
    }
    function test_revokeNonExistentAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(AddressNotFound.selector));
        permissionControl.revokeAdmin(grantee1);
    }
    function test_transferSuperAdminAsOwner() public {
        address newOwner = address(0x9999);
        permissionControl.tranferSuperAdmin(newOwner);
        assertEq(permissionControl.getSuperAdmin(), newOwner);
    }
    function test_transferSuperAdminAsNonOwner() public {
        vm.prank(grantee1);
        vm.expectRevert(abi.encodeWithSelector(PermissionDenied.selector));
        permissionControl.tranferSuperAdmin(grantee2);
    }
    function test_transferSuperAdminToSameAddress() public {
        vm.expectRevert(abi.encodeWithSelector(SameAddress.selector));
        permissionControl.tranferSuperAdmin(owner);
    }
    function test_adminManagementFlow() public {
        permissionControl.grantAdmin(grantee1);
        permissionControl.grantAdmin(address(0x5678));
        
        address[] memory grantees = permissionControl.getGranteeAdmin();
        assertEq(grantees.length, 2);
        
        permissionControl.revokeAdmin(grantee1);
        
        grantees = permissionControl.getGranteeAdmin();
        assertEq(grantees.length, 1);
        assertEq(grantees[0], address(0x5678));
    }
}