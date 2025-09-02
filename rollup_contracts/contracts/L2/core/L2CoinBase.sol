// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../bridge/interfaces/IL2ETHBridge.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract L2CoinBase is OwnableUpgradeable {
    address public mailbox;

    receive() external payable {
    }

    function initialize(address _mailbox) external initializer {
        OwnableUpgradeable.__Ownable_init();
        mailbox = _mailbox;
    }
    // Withdrawal permission account
    mapping(address => bool) public isWithdrawer;

    // Whitelisted accounts on L1, to which withdrawals can be made
    mapping(address => bool) public whiteListOnL1;

    modifier onlyWithdrawer() {
        // @note In the decentralized mode, it should be only called by a list of validator.
        require(isWithdrawer[_msgSender()], "INVALID_PERMISSION : sender is not withdrawer");
        _;
    }

    event SetMailbox(address indexed newMailbox);

    event AddWithdrawer(address indexed newWithdrawer);

    event RemoveWithdrawer(address indexed oldWithdrawer);

    event AddWhiteAddress(address indexed whiteAddress);

    event RemoveWhiteAddress(address indexed whiteAddress);

    event CoinBaseWithdraw(address indexed _target, uint256 indexed amount);

    function setMailbox(address newMailbox) onlyOwner external {
        mailbox = newMailbox;

        emit SetMailbox(mailbox);
    }

    function addWithdrawer(address newWithdrawer) onlyOwner external {
        isWithdrawer[newWithdrawer] = true;

        emit AddWithdrawer(newWithdrawer);
    }

    function removeWithdrawer(address oldWithdrawer) onlyOwner external {
        isWithdrawer[oldWithdrawer] = false;

        emit RemoveWithdrawer(oldWithdrawer);
    }

    function addWhiteAddress(address whiteAddress) onlyOwner external {
        whiteListOnL1[whiteAddress] = true;

        emit AddWhiteAddress(whiteAddress);
    }

    function removeWhiteAddress(address whiteAddress) onlyOwner external {
        whiteListOnL1[whiteAddress] = false;

        emit RemoveWhiteAddress(whiteAddress);
    }

    function withdraw(address _target, uint256 amount) onlyWithdrawer public {
        require(whiteListOnL1[_target], "INVALID_PERMISSION : target is not receiver on L1");
        require(amount <= address(this).balance, "INVALID_PERMISSION : withdraw amount must smaller than or equal to balance");

        bytes memory message_ = abi.encodeCall(IL2ETHBridge.withdraw, (_target, amount, 0, ""));
        (bool success_, ) = mailbox.call{value : amount}(message_);
        require(success_, "withdraw failed in L2EthBridge");
        emit CoinBaseWithdraw(_target, amount);
    }

    function withdrawAll(address _target) onlyWithdrawer external {
        withdraw(_target,address(this).balance);
    }
}