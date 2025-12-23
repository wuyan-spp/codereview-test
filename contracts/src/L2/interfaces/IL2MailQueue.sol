// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IL2MailQueue {
    /**
     * @dev Returns the message root.
     */
    function msgRoot() external view returns (bytes32);
}
