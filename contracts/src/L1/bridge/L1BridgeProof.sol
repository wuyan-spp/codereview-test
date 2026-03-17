// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


/// @custom:security-contact enxi.zys@antgroup.com
contract L1BridgeProof is BridgeBase, IL1BridgeProof {
    function relayMsgWithProof(uint256 value_, uint256 nonce_, bytes memory msg_, IL1Mailbox.L2MsgProof memory proof_)
        external
        whenNotPaused
    {
        mailBoxCall(
            abi.encodeCall(IL1Mailbox.relayMsgWithProof, (toBridge, address(this), value_, nonce_, msg_, proof_))
        );
    }
}
