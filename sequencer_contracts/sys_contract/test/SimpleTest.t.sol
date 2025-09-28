// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/Test.sol";
import "../artifact_src/solidity/sys_chaincfg.sol";
contract SimpleTest is Test {
    ChainCfg public chainCfg;
    
    function setUp() public {
        chainCfg = new ChainCfg();
    }
    
    function test_basic() public view {
        assertTrue(true);
    }
}
