// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IRule} from "./interface/IRule.sol";
import {IL2RuleManager} from "./interface/IL2RuleManager.sol";

contract L2RuleManager is OwnableUpgradeable, IL2RuleManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    string constant private RULE_CAN_WITHDRAW = "CAN_WITHDRAW";

    EnumerableSet.Bytes32Set private rules; // existed rule names, eg. keccak256(bytes("CAN_WITHDRAW"))
    mapping(string => EnumerableSet.AddressSet) private ruleToBizContract; // "CAN_WITHDRAW" -> bizContract1, bizContract2
    mapping(address => mapping(string => EnumerableSet.AddressSet)) private bizContractToRuleCA; // bizContract -> "CAN_WITHDRAW" -> ruleAddress1, ruleAddress2

    event RuleAdded(string[] types);
    event RuleRemoved(string[] types);
    event RuleRegisterd(address bizContract, string rule, address[] cas);
    event RuleUnregisterd(address bizContract, string rule, address[] cas);

    error EmptyRuleContracts();
    error NotSupportRule();

    constructor() {
        _disableInitializers();
    }

    modifier onlyContract() {
        require(isContract(msg.sender), "Caller is not a contract");
        _;
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    function canWithdraw(address sender_, address to_, uint256 amount_, uint256 gasLimit_, bytes memory msg_) external onlyContract {
        EnumerableSet.AddressSet storage caSet = bizContractToRuleCA[msg.sender][RULE_CAN_WITHDRAW];
        uint256 caLen = caSet.length();
        for(uint256 i = 0; i < caLen; ++i) {
            IRule(caSet.at(i)).withdrawCheck(msg.sender, sender_, to_, amount_, gasLimit_, msg_);
        }
    }

    // add rules
    function addRules(string[] calldata rules_) external onlyOwner {
        for (uint i = 0; i < rules_.length; ++i) {
            rules.add(stringToHash(rules_[i]));
        }
        emit RuleAdded(rules_);
    }

    // remove rules
    function removeRules(string[] calldata rules_) external onlyOwner {
        for (uint i = 0; i < rules_.length; ++i) {
            require(ruleToBizContract[rules_[i]].length() == 0, "rule is in use");
            rules.remove(stringToHash(rules_[i]));
        }
        emit RuleRemoved(rules_);
    }

    // contract regists rules
    function registerRules(string calldata rule_, address[] calldata cas_) external onlyContract {
        _checkRules(rule_, cas_);
        ruleToBizContract[rule_].add(msg.sender);
        for (uint i = 0; i < cas_.length; ++i) {
            bizContractToRuleCA[msg.sender][rule_].add(cas_[i]);
        }
        emit RuleRegisterd(msg.sender, rule_, cas_);
    }

    // contract unregists rules
    function unregisterRules(string calldata rule_, address[] calldata cas_) external onlyContract {
        _checkRules(rule_, cas_);
        require(bizContractToRuleCA[msg.sender][rule_].length() > 0, "no rule contracts");
        for (uint i = 0; i < cas_.length; ++i) {
            bizContractToRuleCA[msg.sender][rule_].remove(cas_[i]);
        }

        if (bizContractToRuleCA[msg.sender][rule_].length() == 0) {
            ruleToBizContract[rule_].remove(msg.sender);
        }
        emit RuleUnregisterd(msg.sender, rule_, cas_);
    }

    function supportRule(string calldata rule_) public view returns (bool) {
        return rules.contains(stringToHash(rule_));
    }

    function isRuleUsedByBizContract(address bizContract_, string calldata rule_, address ca_) external view returns (bool) {
        return bizContractToRuleCA[bizContract_][rule_].contains(ca_);
    }

    function getBizContractsOfRule(string calldata rule_) external view returns(address[] memory) {
        return ruleToBizContract[rule_].values();
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function stringToHash(string calldata str) internal pure returns (bytes32) {
        return keccak256(bytes(str));
    }

    function _checkRules(string calldata rule_, address[] calldata cas_) internal {
        if (!supportRule(rule_)) {
            revert NotSupportRule();
        }
        if (cas_.length == 0) {
            revert EmptyRuleContracts();
        }
    }
}