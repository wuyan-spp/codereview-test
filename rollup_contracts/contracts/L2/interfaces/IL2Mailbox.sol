// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IMailBoxBase} from "../../common/interfaces/IMailBoxBase.sol";

interface IL2Mailbox is IMailBoxBase {
    /**
     * Send L1 message to current L2 through Relayer, and execute the corresponding message in L2 bridge contract
     * @param sender_ sender L1 bridge contract address
     * @param target_ message receiver current L2 bridge contract address
     * @param value_ native token transfer amount
     * @param nonce_ message nonce value
     * @param msg_ message content sent to target_ for execution
     */
    function relayMsg(address sender_, address target_, uint256 value_, uint256 nonce_, bytes calldata msg_) external;

    /**
     * Check deposit eth claim msg is valid or not
     * @param refundAddress the refund address for claim amount
     * @param amount native token deposit failed
     * @param nonce_ message nonce value
     * @param msgHash_ message hash or deposit message
     */
    function claimETH(
        address refundAddress,
        uint256 amount,
        uint256 nonce_,
        bytes32 msgHash_
    ) external;

    /**
     * Check deposit erc20 claim msg is valid or not
     * @param nonce_ deposit message nonce value
     * @param msgHash_ message hash or deposit message
     */
    function claimERC20(
        uint256 nonce_,
        bytes32 msgHash_
    ) external;

    function setMsgOracle(address msgOracle_) external;

    function approveMsg(
        address sender_,
        address target_,
        uint256 value_,
        uint256 nonce_,
        bytes calldata msg_
    ) external;
}
