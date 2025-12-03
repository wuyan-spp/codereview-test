// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRule} from "./interface/IRule.sol";
import {EnumerableSet} from "../../../node_modules/@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract L2WithdrawLimitation is OwnableUpgradeable, IRule {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public bizContract;
    address public l2RuleManager;
    uint256 public cycleETHWithdrawLimit; // ETH withdraw limit per cycle
    uint256 public cycleRemainQuota; // remain quota in current cycle
    uint256 public anchorTime; // anchor time
    uint256 public cycleFromAnchorTime; // use (block.timestamp - anchorTime) / timeCycle to get current cycle number
    uint256 public timeCycle; // cycle in seconds

    EnumerableSet.AddressSet private whitelist;

    event CycleWithdrawLimitCheckPassed(address sender, uint256 amount_);
    event CycleInfoUpdated(uint256 anchorTime_, uint256 cycleFromAnchorTime_, uint256 cycleETHWithdrawLimit_, uint256 cycleRemainQuota_);
    event AnchorTimeUpdated(uint256 newAnchorTime_);
    event TimeCycleUpdated(uint256 newTimeCycle_);
    event RuleManagerUpdated(address newL2RuleManager_);
    event BizContractUpdated(address newBizContract_);
    event WhitelistAdded(address[] newWhitelistAddresses_);
    event WhitelistRemoved(address[] removedWhitelistAddresses_);

    constructor() {
         _disableInitializers();
    }

    modifier onlyL2RuleManager() {
        require(msg.sender == l2RuleManager, "caller is not l2RuleManager");
        _;
    }

    function initialize(uint256 cycleETHWithdrawLimit_, uint256 timeCycle_, address bindBizContract_, address l2RuleManager_) external initializer {
        __Ownable_init();
        anchorTime = block.timestamp;
        timeCycle = timeCycle_;

        cycleETHWithdrawLimit = cycleETHWithdrawLimit_;
        cycleRemainQuota = cycleETHWithdrawLimit_;
        bizContract = bindBizContract_;
        l2RuleManager = l2RuleManager_;
    }

    function setAnchorTime(uint256 anchorTime_) external onlyOwner {
        anchorTime = anchorTime_;
        cycleFromAnchorTime = 0;
        cycleRemainQuota = cycleETHWithdrawLimit;

        emit AnchorTimeUpdated(anchorTime_);
    }

    function setTimeCycle(uint256 timeCycle_) external onlyOwner {
        timeCycle = timeCycle_;
        anchorTime = block.timestamp;
        cycleFromAnchorTime = 0;
        cycleRemainQuota = cycleETHWithdrawLimit;

        emit TimeCycleUpdated(timeCycle_);
    }

    function setRuleManager(address l2RuleManager_) external onlyOwner {
        require(l2RuleManager_ != address(0), "l2RuleManager is zero address");
        l2RuleManager = l2RuleManager_;
        emit RuleManagerUpdated(l2RuleManager_);
    }

    function setBizContract(address bindBizContract_) external onlyOwner {
        require(bindBizContract_ != address(0), "bindBizContract is zero address");
        bizContract = bindBizContract_;
        emit BizContractUpdated(bindBizContract_);
    }

    function withdrawCheck(address caller_, address sender_, address, uint256 amount_, uint256, bytes calldata) external onlyL2RuleManager {
        require(caller_ == bizContract, "caller is not bizContract");
        require(amount_ > 0, "withdraw ETH amount_ must more than zero");

        if(whitelist.contains(sender_)) {
            emit CycleWithdrawLimitCheckPassed(sender_, amount_);
            return;
        }

        uint256 timeCycle_ = timeCycle;
        uint256 anchorTime_ = anchorTime;

        // check current time is in current cycle
        require(block.timestamp >= cycleFromAnchorTime * timeCycle_ + anchorTime_, "Block executed at expiration time");

        // if current time is in next cycle, update cycle info
        if(block.timestamp >= (cycleFromAnchorTime+1) * timeCycle_ + anchorTime_) {
            updateCycleInfo(timeCycle_, anchorTime_);
        }
        // check current time is not in next cycle
        require(block.timestamp < (cycleFromAnchorTime+1) * timeCycle_ + anchorTime_ , "previous cycle time update not enough");

        require(amount_ <= cycleRemainQuota, "current cycle remain quota not enough");
        cycleRemainQuota -= amount_;

        emit CycleWithdrawLimitCheckPassed(sender_, amount_);
    }

    function updateCycleInfo(uint256 timeCycle_, uint256 anchorTime_) internal {
        uint256 newCycleFromAnchorTime = (block.timestamp - anchorTime_) / timeCycle_;
        uint256 currCycleETHWithdrawLimit = cycleETHWithdrawLimit;

        cycleFromAnchorTime = newCycleFromAnchorTime;
        cycleRemainQuota = currCycleETHWithdrawLimit;

        emit CycleInfoUpdated(anchorTime, newCycleFromAnchorTime, currCycleETHWithdrawLimit, currCycleETHWithdrawLimit);
    }

    // update cycle info
    function updateCycleETHWithdrawLimit(uint256 cycleETHWithdrawLimit_) external onlyOwner {
        anchorTime = block.timestamp;
        cycleFromAnchorTime = 0;
        cycleETHWithdrawLimit = cycleETHWithdrawLimit_;
        cycleRemainQuota = cycleETHWithdrawLimit_;

        emit CycleInfoUpdated(anchorTime, 0, cycleETHWithdrawLimit_, cycleETHWithdrawLimit_);
    }

    // query latest withdraw limit info
    function queryWithdrawLimit() public view returns (uint256, uint256) {
        uint256 cycleETHWithdrawLimit_ = cycleETHWithdrawLimit;

        // if current time is in next cycle, return new cycle limit info
        if(block.timestamp >= (cycleFromAnchorTime+1) * timeCycle + anchorTime) {
            return (cycleETHWithdrawLimit_, cycleETHWithdrawLimit_);
        } else {
            return (cycleRemainQuota, cycleETHWithdrawLimit_);
        }
    }

    // query if specific addresses in whitelist
    function ifWhitelist(address[] calldata addresses_) public view returns (address[] memory, address[] memory) {
        address[] memory inWhitelist = new address[](addresses_.length);
        address[] memory notInWhitelist = new address[](addresses_.length);
        uint256 inWhitelistCount = 0;
        uint256 notInWhitelistCount = 0;

        for(uint256 i = 0; i < addresses_.length; ++i) {
            if(whitelist.contains(addresses_[i])) {
                inWhitelist[inWhitelistCount] = addresses_[i];
                ++inWhitelistCount;
            } else {
                notInWhitelist[notInWhitelistCount] = addresses_[i];
                ++notInWhitelistCount;
            }
        }

        assembly{
            mstore(inWhitelist, inWhitelistCount)
            mstore(notInWhitelist, notInWhitelistCount)
        }

        return (inWhitelist, notInWhitelist);
    }

    function queryWhitelist() public view returns (address[] memory) {
        return whitelist.values();
    }

    // add addresses to whitelist
    function addToWhitelist(address[] calldata addresses_) external onlyOwner {
        for(uint256 i = 0; i < addresses_.length; ++i) {
            whitelist.add(addresses_[i]);
        }
        emit WhitelistAdded(addresses_);
    }

    function delFromWhitelist(address[] calldata addresses_) external onlyOwner {
        for(uint256 i = 0; i < addresses_.length; ++i) {
            whitelist.remove(addresses_[i]);
        }
        emit WhitelistRemoved(addresses_);
    }
}