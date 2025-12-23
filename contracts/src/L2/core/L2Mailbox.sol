// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AppendOnlyMerkleTree} from "../libraries/common/AppendOnlyMerkleTree.sol";
import {IL2Mailbox} from "../interfaces/IL2Mailbox.sol";
import {IL2MailQueue} from "../interfaces/IL2MailQueue.sol";
import {MailBoxBase} from "../../common/MailBoxBase.sol";

/// @custom:security-contact enxi.zys@antgroup.com
contract L2Mailbox is AppendOnlyMerkleTree, MailBoxBase, IL2Mailbox, IL2MailQueue {
    /// @notice The address of L1MailBox contract.
    address public l1MailBox;

    mapping(bytes32 msgHash => bool status) public receiveMsgStatus;
    mapping(bytes32 => bool) public pendingMsgMap;
    address public msgOracle;

    uint256 public finalizeL1MsgNonce;
    uint256 public version;
    uint256 internal constant ORACLE_VERSION = 1;
    /**
     * Errors
     */
    error NotSupportOracle();

    error NotSupportDownGrade();

    error ErrorL1MsgNonce();

    /**
     * Events
     */
    event Initialized(address indexed l1MailBox, address indexed owner, uint256 baseFee);

    event SetMsgOracle(address indexed _msgOracle);

    event PendingMsg(
        address indexed _sender,
        address indexed _target,
        uint256 _value,
        uint256 _nonce,
        bytes _msg
    );

    event SetFinalizeL1MsgNonce(uint256 _finalizeL1MsgNonce);

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
        emit Initialized(l1MailBox_, owner_, baseFee_);
    }


    function setMsgOracle(address msgOracle_) external onlyOwner {
        require(msgOracle_ != address(0), "msgOracle must not zero");
        require(msgOracle_.code.length != 0, "msgOracle must be contract");
        msgOracle = msgOracle_;
        emit SetMsgOracle(msgOracle_);
    }

    function sendMsg(address target_, uint256 value_, bytes calldata msg_, uint256 gasLimit_, address refundAddress_)
        external
        payable
        override
        onlyBridge
        whenNotPaused
        nonReentrant
    {
        require(refundAddress_ != address(0), "L2Mailbox: refundAddress is zero address");
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
                (bool success_,) = refundAddress_.call{value: refund_}("");
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
    function relayMsg(address sender_, address target_, uint256 value_, uint256 nonce_, bytes calldata msg_)
        external
        override
        whenNotPaused
        nonReentrant
    {
        // here l1MailBox will be set as L2Relayer 0x5100000000000000000000000000000000000000
        require(_msgSender() == l1MailBox, "Caller is not L1Mailbox");
        bytes32 hash_ = keccak256(_encodeCall(sender_, target_, value_, nonce_, msg_));
        _receiveMsgCheck(hash_);

        if (version < ORACLE_VERSION) {
            bytes32 rollinghash = _getRollingHash(hash_);
            emit RollingHash(rollinghash);
            (bool success,) = target_.call{value: value_}(msg_);
            if (success) {
                _receiveMsgSuccess(hash_);
                emit RelayMsgSuccess(hash_, nonce_);
            } else {
                _receiveMsgFailed(hash_);
                emit RelayMsgFailed(hash_, nonce_);
            }
            emit RelayedMsg(hash_, nonce_);
        } else {
            pendingMsgMap[hash_] = true;
            emit PendingMsg(sender_, target_, value_, nonce_, msg_);
        }
    }

    function approveMsg(
        address sender_,
        address target_,
        uint256 value_,
        uint256 nonce_,
        bytes calldata msg_
    ) external override whenNotPaused nonReentrant {
        if (version >= ORACLE_VERSION) {
            require(_msgSender() == msgOracle, "Caller is not msgOracle");
            if (finalizeL1MsgNonce != nonce_) {
                revert ErrorL1MsgNonce();
            }
            bytes32 hash_ = keccak256(_encodeCall(sender_, target_, value_, nonce_, msg_));
            require(pendingMsgMap[hash_], "msg is not in pending stage");
            delete pendingMsgMap[hash_];
            bytes32 rollinghash = _getRollingHash(hash_);
            emit RollingHash(rollinghash);
            ++finalizeL1MsgNonce;
            (bool success,) = target_.call{value : value_}(msg_);
            if (success) {
                _receiveMsgSuccess(hash_);
                emit RelayMsgSuccess(hash_, nonce_);
            } else {
                _receiveMsgFailed(hash_);
                emit RelayMsgFailed(hash_, nonce_);
            }
            emit RelayedMsg(hash_, nonce_);
        } else {
            revert NotSupportOracle();
        }
    }

    function claimETH(
        address refundAddress_,
        uint256 amount_,
        uint256 nonce_,
        bytes32 msgHash_
    ) external override onlyBridge whenNotPaused nonReentrant {
        require(refundAddress_ != address(0), "L2Mailbox: refundAddress is zero address");
        _checkMsgClaimValid(msgHash_);
        (bool success,) = refundAddress_.call{value : amount_}("");
        require(success, "claim amount failed when transfer to refund");

        emit ClaimMsg(msgHash_, nonce_);
    }

    function claimERC20(
        uint256 nonce_,
        bytes32 msgHash_
    ) external override onlyBridge whenNotPaused nonReentrant {
        _checkMsgClaimValid(msgHash_);
        emit ClaimMsg(msgHash_, nonce_);
    }

    function setFinalizeL1MsgNonce(uint256 _finalizeL1MsgNonce) external onlyOwner whenPaused {
        finalizeL1MsgNonce = _finalizeL1MsgNonce;
        if (version > ORACLE_VERSION) {
            revert NotSupportDownGrade();
        } else {
            version = ORACLE_VERSION;
        }
        emit SetFinalizeL1MsgNonce(_finalizeL1MsgNonce);
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

    function _receiveMsgFailed(bytes32 hash_) internal {
        receiveMsgStatus[hash_] = false;
    }

    function _receiveMsgSuccess(bytes32 hash_) internal {
        receiveMsgStatus[hash_] = true;
    }

    function _checkMsgClaimValid(bytes32 hash_) internal {
        _msgExistCheck(hash_);
        require(!receiveMsgStatus[hash_], "ClaimMsg : L2 msg must exec failed before");
        receiveMsgStatus[hash_] = true;
    }
}
