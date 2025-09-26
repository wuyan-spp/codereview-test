// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../artifact_src/solidity/sys_chaincfg.sol";

contract ChainCfgTest is Test {
    ChainCfg public chainCfg;
    address public constant SYS_STAKING = 0x4100000000000000000000000000000000000000;
    address public constant INTRINSIC_SYS = 0x1111111111111111111111111111111111111111;

    error NotOwner();

    error KeysAndValuesLengthMismatch();

    function setUp() public {
        chainCfg = new ChainCfg();
    }
    function test_initialState() public view {
        assertEq(chainCfg.rootSys(), address(0));
    }
    function test_setConfigAsSysStaking() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "test.key";
        values[0] = "test.value";
        vm.prank(SYS_STAKING);
        chainCfg.set_config(keys, values);
    }
    function test_setConfigAsIntrinsicSys() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "test.key";
        values[0] = "test.value";
        vm.prank(INTRINSIC_SYS);
        chainCfg.set_config(keys, values);
    }
    function test_setConfigUnauthorized() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "test.key";
        values[0] = "test.value";
        vm.prank(address(0x1234));
        vm.expectRevert(abi.encodeWithSelector(NotOwner.selector));
        chainCfg.set_config(keys, values);
    }
    function test_setConfigKeysValuesMismatch() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](2);
        keys[0] = "key";
        values[0] = "value1";
        values[1] = "value2";
        vm.prank(INTRINSIC_SYS);
        vm.expectRevert(abi.encodeWithSelector(KeysAndValuesLengthMismatch.selector));
        chainCfg.set_config(keys, values);
    }
    function test_getNonExistentConfig() public view {
        assertEq(chainCfg.get_config("nonexistent"), "");
    }
    function test_changeSysOwner() public {
        address newOwner = address(0x1234);
        vm.prank(INTRINSIC_SYS);
        chainCfg.changeSys(newOwner);
        assertEq(chainCfg.rootSys(), newOwner);
    }
}