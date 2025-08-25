// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AppendOnlyMerkleTree} from "../libraries/common/AppendOnlyMerkleTree.sol";
import "../interfaces/IL2Mailbox.sol";
import "../interfaces/IL2MailQueue.sol";
import "../../common/MailBoxBase.sol";

contract L2Mailbox is AppendOnlyMerkleTree, MailBoxBase, IL2Mailbox, IL2MailQueue {
    /// @notice The address of L1MailBox contract.
    address public l1MailBox;

    constructor(){
        _disableInitializers();
    }

    /**
     * Contract initialization
     * @param l1MailBox_ L1MailBox contract address
     * @param owner_ Contract owner address
     * @param baseFee_ Message sender token transfer amount
     */
    function initialize(address l1MailBox_, address owner_, uint256 baseFee_) external initializer {
        if (l1MailBox_ == address(0) || owner_ == address(0)) {
            revert InvalidInitAddress();
        }
        require(_nextMsgIndex == 0, "msg index is not 0");
        __MailBox_init();

        l1MailBox = l1MailBox_;
        baseFee = baseFee_;
        _transferOwnership(owner_);
        _initializeMerkleTree();
    }

    function setL1MailBox(address l1MailBox_) external onlyOwner {
        require(l1MailBox_ != address(0), "Invalid address");
        l1MailBox = l1MailBox_;
    }

    function sendMsg(
        address target_,
        uint256 value_,
        bytes calldata msg_,
        uint256 gasLimit_,
        address refundAddress_
    ) external payable override onlyBridge whenNotPaused nonReentrant {

        // compute the actual cross domain message calldata.
        uint256 nonce_ = _nextMsgIndex;
        bytes memory data_ = _encodeCall(_msgSender(), target_, value_, nonce_, msg_);

        // Calculate the fee and keep it in the MailBox contract
        uint256 fee_ = estimateMsgFee(gasLimit_);
        require(msg.value >= fee_ + value_, "Insufficient msg.value");

        bytes32 hash_ = keccak256(data_);
        // normally this won't happen, since each message has different nonce, but just in case.
        _sendMsgCheck(hash_);
        // append message to L2MailQueue
        _appendMsg(hash_);

        emit SentMsg(_msgSender(), target_, value_, nonce_, msg_, gasLimit_, hash_);

        // refund fee to `refundAddress_`
        unchecked {
            uint256 refund_ = msg.value - fee_ - value_;
            if (refund_ > 0) {
                (bool success_,) = refundAddress_.call{value : refund_}("");
                require(success_, "Failed to refund the fee");
            }
        }
    }

    /**
     * Send L1 message to current L2 through Relayer
     * @param sender_ sender L1 bridge contract address
     * @param target_ message receiver current L2 bridge contract address
     * @param value_ native token transfer amount
     * @param nonce_ message queue nonce
     * @param msg_ message content sent to target_ execution
     */
    function relayMsg(
        address sender_,
        address target_,
        uint256 value_,
        uint256 nonce_,
        bytes calldata msg_
    ) external override whenNotPaused nonReentrant {
        // here l1MailBox will be set as L2Relayer 0x5100000000000000000000000000000000000000
        require(_msgSender() == l1MailBox, "Caller is not L1Mailbox");

        bytes32 hash_ = keccak256(_encodeCall(sender_, target_, value_, nonce_, msg_));

        (bool success,) = target_.call{value : value_}(msg_);
        require(success, "RelayMsg Failed");
        _receiveMsgCheck(hash_);
        bytes32 rollinghash = _getRollingHash(hash_);
        emit RollingHash(rollinghash);
        emit RelayedMsg(hash_, nonce_);
    }

    /**
     * @dev Appends a message to the queue.
     */
    function _appendMsg(bytes32 msgHash) internal override {
        (uint256 currentNonce,) = _appendMsgHash(msgHash);
        // We can use the event to compute the merkle tree locally.
        emit AppendMsg(currentNonce, msgHash);
    }

    function msgRoot() external view returns (bytes32) {
        return _msgRoot;
    }
}
