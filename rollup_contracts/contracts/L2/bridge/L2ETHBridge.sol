// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IL1ETHBridge} from "../../L1/bridge/interfaces/IL1ETHBridge.sol";
import {BridgeBase} from "../../common/BridgeBase.sol";
import {IL2Mailbox, IMailBoxBase} from "../interfaces/IL2Mailbox.sol";
import {IL2ETHBridge} from "./interfaces/IL2ETHBridge.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {IL2RuleManager} from "../rule/interface/IL2RuleManager.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/// @custom:security-contact enxi.zys@antgroup.com
contract L2ETHBridge is BridgeBase, IL2ETHBridge {
    using AddressUpgradeable for address;

    uint256 public balance;

    address public ruleManager;

    bool public isRuleCheck;

    event RuleCheckSwitched(bool);
    event SetRuleManager(address);

    event DepositClaimed(address indexed target, uint256 amount, bytes32 depositHash);
    event DepositClaimedWithRefund(address indexed newRefundAddress, uint256 amount, bytes32 depositHash);

    function setRuleManager(address ruleManager_) external onlyOwner {
        require(ruleManager_ != address(0), "ruleManager should not be zero address");
        ruleManager = ruleManager_;
        emit SetRuleManager(ruleManager_);
    }

    function switchRuleCheck() external onlyOwner {
        if(isRuleCheck) {
            isRuleCheck = false;
        } else {
            isRuleCheck = true;
        }
        emit RuleCheckSwitched(isRuleCheck);
    }

    function registerRules(string calldata rule_, address[] calldata cas_) external onlyOwner {
        require(ruleManager != address(0), "ruleManager is not set");
        IL2RuleManager(ruleManager).registerRules(rule_, cas_);
    }

    function unregisterRules(string calldata rule_, address[] calldata cas_) external onlyOwner {
        require(ruleManager != address(0), "ruleManager is not set");
        IL2RuleManager(ruleManager).unregisterRules(rule_, cas_);
    }

    /**
     * The sender account transfers to tokenbridge to lock the assets;
     * @param to_ target address
     * @param amount_ transfer amount
     * @param gasLimit_ gas limit
     * @param msg_ data
     */
    function withdraw(address to_, uint256 amount_, uint256 gasLimit_, bytes memory msg_)
        external
        payable
        override
        nonReentrant
        whenNotPaused
    {
        require(to_ != address(0), "L2ETHBridge: to is zero address");
        require(msg.value > 0, "withdraw zero eth");
        require(amount_ > 0, "withdraw zero amount");

        require(balance >= amount_, "insufficient balance");

        address sender_ = _msgSender();

        if(isRuleCheck) {
            require(ruleManager != address(0), "ruleManager is not set");
            ruleManager.functionCall(abi.encodeCall(IL2RuleManager.canWithdraw, (sender_, to_, amount_, gasLimit_, msg_)), "rule manager withdraw check failed");
        }

        bytes memory message_ = abi.encodeCall(IL1ETHBridge.finalizeWithdraw, (sender_, to_, amount_, msg_));
        balance -= amount_;
        mailBoxCall(abi.encodeCall(IMailBoxBase.sendMsg, (toBridge, amount_, message_, gasLimit_, sender_)));
        emit WithdrawETH(sender_, to_, amount_, message_);
    }

    /**
     * Complete the transfer of L1 assets
     * @param sender_ transfer initiator
     * @param to_ target address
     * @param amount_ transfer amount
     * @param msg_ data
     */
    function finalizeDeposit(address sender_, address to_, uint256 amount_, bytes calldata msg_)
        external
        payable
        override
        nonReentrant
        onlyMailBox
        whenNotPaused
    {
        require(to_ != address(0), "L2ETHBridge: to is zero address");
        require(msg.value == amount_, "msg.value mismatch");
        balance += amount_;

        // Base gas reserved for operations after the external call
        uint256 BASE_POST_CALL_GAS = 5000;
        // Each byte in calldata costs 8 gas for event emission (G_txdatanonzero = 8)
        uint256 post_call_reserve_gas = BASE_POST_CALL_GAS + 8 * msg_.length;
        require(gasleft() > post_call_reserve_gas, "L2ETHBridge.finalizeDeposit: not enough gas");
        (bool success_,) = to_.call{value : amount_, gas : gasleft() - post_call_reserve_gas}("");
        require(success_, "ETH transfer failed");

        emit FinalizeDepositETH(sender_, to_, amount_, msg_);
    }

    function claimDeposit(bytes calldata msg_) external override nonReentrant whenNotPaused {
        (address l1bridge, address l2bridge, uint256 value, uint256 nonce, bytes memory depositMsg) =
            abi.decode(msg_[4:], (address, address, uint256, uint256, bytes));
        bytes memory newDepositMsg = BytesLib.slice(depositMsg, 4, depositMsg.length - 4);
        (address sender, address target, uint256 amount, bytes memory data) =
            abi.decode(newDepositMsg, (address, address, uint256, bytes));
        bytes32 depositHash = keccak256(msg_);
        balance += amount;
        IL2Mailbox(mailBox).claimETH(target, amount, nonce, depositHash);
        emit DepositClaimed(target, amount, depositHash);
    }

    function claimDeposit(bytes calldata msg_, address new_refund_address_)
        external
        override
        nonReentrant
        whenNotPaused
    {
        (address l1bridge, address l2bridge, uint256 value, uint256 nonce, bytes memory depositMsg) =
            abi.decode(msg_[4:], (address, address, uint256, uint256, bytes));
        bytes memory newDepositMsg = BytesLib.slice(depositMsg, 4, depositMsg.length - 4);
        (address sender, address target, uint256 amount, bytes memory data) =
            abi.decode(newDepositMsg, (address, address, uint256, bytes));
        bytes32 depositHash = keccak256(msg_);
        balance += amount;
        require(msg.sender == sender, "claimDeposit change refund must called by origin sender");
        IL2Mailbox(mailBox).claimETH(new_refund_address_, amount, nonce, depositHash);
        emit DepositClaimedWithRefund(new_refund_address_, amount, depositHash);
    }
}
