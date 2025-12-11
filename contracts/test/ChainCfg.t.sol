// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import "forge-std/Test.sol";
import {ChainCfg} from "../src/L2/sys/ChainCfg.sol";

contract ChainCfgTest is Test {
    ChainCfg public chainCfg;
    CheckDuplicateKeysTester public tester;
    address public constant SYS_STAKING = 0x4100000000000000000000000000000000000000;
    address public constant INTRINSIC_SYS = 0x1111111111111111111111111111111111111111;

    error NotOwner();

    error KeysAndValuesLengthMismatch();

    function setUp() public {
        chainCfg = new ChainCfg();
        tester = new CheckDuplicateKeysTester();
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

    // ===== Unit tests for _checkDuplicateKeys function =====

    function testCheckDuplicateKeys_EmptyArray() public view {
        string[] memory keys = new string[](0);
        assertTrue(tester.checkDuplicateKeys(keys));
    }

    function testCheckDuplicateKeys_SingleKey() public view {
        string[] memory keys = new string[](1);
        keys[0] = "single_key";
        assertTrue(tester.checkDuplicateKeys(keys));
    }

    function testCheckDuplicateKeys_NoDuplicates() public view {
        string[] memory keys = new string[](3);
        keys[0] = "key1";
        keys[1] = "key2";
        keys[2] = "key3";
        assertTrue(tester.checkDuplicateKeys(keys));
    }

    function testCheckDuplicateKeys_HasDuplicates() public view {
        string[] memory keys = new string[](3);
        keys[0] = "key1";
        keys[1] = "key2";
        keys[2] = "key1"; // duplicate key
        assertFalse(tester.checkDuplicateKeys(keys));
    }

    function testCheckDuplicateKeys_AllDuplicates() public view {
        string[] memory keys = new string[](3);
        keys[0] = "same_key";
        keys[1] = "same_key";
        keys[2] = "same_key";
        assertFalse(tester.checkDuplicateKeys(keys));
    }

    function testCheckDuplicateKeys_CaseSensitive() public view {
        string[] memory keys = new string[](2);
        keys[0] = "Key";
        keys[1] = "key"; // different case, should not be considered duplicate
        assertTrue(tester.checkDuplicateKeys(keys));
    }

    // ===== Integration tests for set_config interface duplicate key checking =====

    function testSetConfig_NoDuplicateKeys() public {
        string[] memory keys = new string[](2);
        string[] memory values = new string[](2);
        keys[0] = "key1";
        keys[1] = "key2";
        values[0] = "value1";
        values[1] = "value2";

        vm.prank(INTRINSIC_SYS);
        chainCfg.set_config(keys, values); // should succeed

        // Configuration becomes effective in the next block, so advance the block
        vm.roll(block.number + 1);

        assertEq(chainCfg.get_config("key1"), "value1");
        assertEq(chainCfg.get_config("key2"), "value2");
    }

    function testSetConfig_WithDuplicateKeys() public {
        string[] memory keys = new string[](3);
        string[] memory values = new string[](3);
        keys[0] = "key1";
        keys[1] = "key2";
        keys[2] = "key1"; // duplicate key
        values[0] = "value1";
        values[1] = "value2";
        values[2] = "value3";

        vm.prank(INTRINSIC_SYS);
        vm.expectRevert("KEYS_DUPLICATE");
        chainCfg.set_config(keys, values);
    }

    function testSetConfig_UpdateExistingKey() public {
        // First configuration setup
        string[] memory keys1 = new string[](2);
        string[] memory values1 = new string[](2);
        keys1[0] = "key1";
        keys1[1] = "key2";
        values1[0] = "value1";
        values1[1] = "value2";

        vm.prank(INTRINSIC_SYS);
        chainCfg.set_config(keys1, values1);

        // Advance block to make configuration effective
        vm.roll(block.number + 1);

        // Verify initial configuration
        assertEq(chainCfg.get_config("key1"), "value1");
        assertEq(chainCfg.get_config("key2"), "value2");

        // Update existing key value (this should be allowed and not trigger duplicate key check failure)
        string[] memory keys2 = new string[](1);
        string[] memory values2 = new string[](1);
        keys2[0] = "key1"; // update existing key
        values2[0] = "updated_value1";

        vm.prank(INTRINSIC_SYS);
        chainCfg.set_config(keys2, values2); // should succeed

        // Advance block to make update effective
        vm.roll(3); // configuration becomes effective at block 3

        assertEq(chainCfg.get_config("key1"), "updated_value1");
        assertEq(chainCfg.get_config("key2"), "value2"); // key2 should remain unchanged
    }

    function testSetConfig_ComplexScenario() public {
        // First configuration setup
        string[] memory keys1 = new string[](3);
        string[] memory values1 = new string[](3);
        keys1[0] = "network.id";
        keys1[1] = "consensus.type";
        keys1[2] = "block.time";
        values1[0] = "1";
        values1[1] = "pos";
        values1[2] = "3000";

        vm.prank(INTRINSIC_SYS);
        chainCfg.set_config(keys1, values1);

        // Advance block to make initial configuration effective
        vm.roll(block.number + 1);

        // Verify initial configuration
        assertEq(chainCfg.get_config("network.id"), "1");
        assertEq(chainCfg.get_config("consensus.type"), "pos");
        assertEq(chainCfg.get_config("block.time"), "3000");

        // Attempt to set new configuration with duplicate keys, should fail
        string[] memory keys2 = new string[](2);
        string[] memory values2 = new string[](2);
        keys2[0] = "network.id"; // existing key
        keys2[1] = "network.id"; // duplicate key
        values2[0] = "2";
        values2[1] = "2";

        vm.prank(INTRINSIC_SYS);
        vm.expectRevert("KEYS_DUPLICATE");
        chainCfg.set_config(keys2, values2);

        // Verify original configuration was not modified
        assertEq(chainCfg.get_config("network.id"), "1");
        assertEq(chainCfg.get_config("consensus.type"), "pos");
        assertEq(chainCfg.get_config("block.time"), "3000");
    }
}

// Helper contract for testing internal functions
contract CheckDuplicateKeysTester {
    function checkDuplicateKeys(string[] calldata keys) external pure returns (bool) {
        for (uint256 i = 0; i < keys.length; i++) {
            for (uint256 j = i + 1; j < keys.length; j++) {
                if (
                    keccak256(abi.encodePacked(keys[i])) ==
                    keccak256(abi.encodePacked(keys[j]))
                ) {
                    return false;
                }
            }
        }
        return true;
    }
}
