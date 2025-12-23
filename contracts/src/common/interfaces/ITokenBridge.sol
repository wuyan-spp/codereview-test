// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface ITokenBridge {
    event TokenMappingChanged(address indexed token, address indexed tokenTo);

    /**
     * set token mapping
     * @param token_; this chain token address
     * @param tokenTo_; target chain token address
     */
    function setTokenMapping(address token_, address tokenTo_) external payable;
}
