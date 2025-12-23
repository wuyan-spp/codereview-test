// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IBridgeBase {
    error InvalidInitAddress();
    error ErrorCallerIsNotMailBox();

    function pause() external;

    function unpause() external;
}
