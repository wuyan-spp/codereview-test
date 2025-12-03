// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IL2RuleManager {
    function registerRules(string calldata rule_, address[] calldata cas_) external;

    function unregisterRules(string calldata rule_, address[] calldata cas_) external;

    function addRules(string[] calldata rules_) external;

    function removeRules(string[] calldata rules_) external;

    function canWithdraw(address sender_, address to_, uint256 amount_, uint256 gasLimit_, bytes memory msg_) external;
}