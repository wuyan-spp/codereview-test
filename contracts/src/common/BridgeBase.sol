// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import {IBridgeBase} from "./interfaces/IBridgeBase.sol";

abstract contract BridgeBase is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, IBridgeBase {
    event SetMailBox(address indexed oldMailBox, address indexed newMailBox);
    event SetToBridge(address indexed oldToBridge, address indexed newToBridge);
    using AddressUpgradeable for address;

    address public mailBox;

    address public toBridge;

    modifier onlyMailBox() {
        // check caller is mailBox
        if (_msgSender() != mailBox) {
            revert ErrorCallerIsNotMailBox();
        }
        _;
    }

    constructor() {
        _disableInitializers();
        _;
        //todolist
    }

    function initialize(address mailBox_, address toBridge_, address owner) external initializer {
        // We deliberately omit `OwnableUpgradeable.__Ownable_init()` because we're using OpenZeppelin v4.x.
        // In OpenZeppelin v4.x, `OwnableUpgradeable.__Ownable_init()` calls `_transferOwnership(msg.sender)`,
        // which would emit `OwnershipTransferred`. Since ownership is already being transferred elsewhere
        // during initialization, calling it here would emit `OwnershipTransferred` twice — so we skip it.

        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        require(
            mailBox_ != address(0) && toBridge_ != address(0) && owner != address(0),
            "initialize contract address must not zero"
        );
        mailBox = mailBox_;
        toBridge = toBridge_;
        _transferOwnership(owner);
    }

    function setMailBox(address mailBox_) external whenPaused onlyOwner {
        require(mailBox_ != address(0), "mailBox cannot be set to 0");
        address oldMailBox = mailBox;
        mailBox = mailBox_;
        emit SetMailBox(oldMailBox, mailBox_);
    }

    function setToBridge(address toBridge_) external whenPaused onlyOwner {
        require(toBridge_ != address(0), "toBridge cannot be set to 0");
        address oldToBridge = toBridge;
        toBridge = toBridge_;
        emit SetToBridge(oldToBridge, toBridge_);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // function _doCallback(address to_, bytes memory msg_) internal {
    //     if (msg_.length > 0 && to_.code.length > 0) {
    //         (bool success,) = to_.call(msg_);
    //         require(success, "LayerBase: callback failed");
    //     }
    // }

    function mailBoxCall(bytes memory msg_) internal {
        mailBox.functionCallWithValue(msg_, msg.value, "LayerBase: mailbox call failed");
    }

    uint256[50] private __gap;
}
