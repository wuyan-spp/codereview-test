// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BridgeBase} from "./BridgeBase.sol";
import {ITokenBridge} from "./interfaces/ITokenBridge.sol";

abstract contract TokenBridge is BridgeBase, ITokenBridge {
    mapping(address token => address toToken) public tokenMapping;

    mapping(address token => uint256 balance) public balanceOf;

    function setTokenMapping(address token_, address tokenTo_) public payable virtual override whenNotPaused {
        tokenMapping[token_] = tokenTo_;
        emit TokenMappingChanged(token_, tokenTo_);
    }

    function _increaseBalance(address token_, uint256 amount_) internal {
        balanceOf[token_] += amount_;
    }

    function _decreaseBalance(address token_, uint256 amount_) internal {
        require(balanceOf[token_] >= amount_, "TokenBridge: balance not enough");
        balanceOf[token_] -= amount_;
    }

    uint256[50] private __gap;
}
