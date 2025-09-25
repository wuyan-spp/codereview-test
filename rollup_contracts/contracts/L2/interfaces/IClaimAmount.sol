// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IClaim {
    function claimETH(
        bytes calldata msg_
    ) external;

    function claimETH(
        bytes calldata msg_,
        address refundAddress_
    ) external;

    function claimERC20(
        uint256 nonce_,
        bytes32 msgHash_
    ) external;
}
