// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IClaim {
    function claimAmount(
        bytes calldata msg_
    ) external;

    function claimAmount(
        bytes calldata msg_,
        address refundAddress_
    ) external;
}
