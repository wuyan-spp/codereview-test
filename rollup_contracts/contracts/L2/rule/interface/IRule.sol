// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IRule {
    function withdrawCheck(address caller_, address sender_, address to_, uint256 amount_, uint256 gasLimit_, bytes calldata msg_) external;
}