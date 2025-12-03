// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import "forge-std/Test.sol";
import {ChainCfg} from "../src/L2/sys/ChainCfg.sol";

contract SimpleTest is Test {
    ChainCfg public chainCfg;
    
    function setUp() public {
        chainCfg = new ChainCfg();
    }
    
    function test_basic() public view {
        assertTrue(true);
    }
}
