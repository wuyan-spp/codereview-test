// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IL2ETHBridge.sol";
import "../../common/BridgeBase.sol";
import "../interfaces/IL2Mailbox.sol";
import "../../L1/bridge/interfaces/IL1ETHBridge.sol";

contract L2ETHBridge is BridgeBase, IL2ETHBridge {
    uint256 public balance;

    /**
     * The sender account transfers to tokenbridge to lock the assets;
     * @param to_ target address
     * @param amount_ transfer amount
     * @param gasLimit_ gas limit
     * @param msg_ data
     */
    function withdraw(address to_, uint256 amount_, uint256 gasLimit_, bytes memory msg_) external payable override nonReentrant whenNotPaused {
        require(msg.value > 0, "withdraw zero eth");
        require(amount_ > 0, "withdraw zero amount");
        require(gasLimit_ > 0, "withdraw zero gas limit");

        require(balance >= amount_, "insufficient balance");

        address sender_ = _msgSender();

        bytes memory message_ = abi.encodeCall(IL1ETHBridge.finalizeWithdraw, (sender_, to_, amount_, msg_));
        mailBoxCall(abi.encodeCall(IMailBoxBase.sendMsg, (toBridge, amount_, message_, gasLimit_, sender_)));
        balance -= amount_;
        emit WithdrawETH(sender_, to_, amount_, message_);
    }


    /**
     * Complete the transfer of L1 assets
     * @param sender_ transfer initiator
     * @param to_ target address
     * @param amount_ transfer amount
     * @param msg_ data
     */
    function finalizeDeposit(address sender_, address to_, uint256 amount_, bytes calldata msg_) external payable override nonReentrant onlyMailBox whenNotPaused {
        require(msg.value == amount_, "msg.value mismatch");

        (bool success_,) = to_.call{value : amount_}("");
        require(success_, "ETH transfer failed");
        balance += amount_;
// TODO : add call msg with deposit
//        _doCallback(to_, msg_);

        emit FinalizeDepositETH(sender_, to_, amount_, msg_);
    }
}
