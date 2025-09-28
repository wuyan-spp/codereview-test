// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IL2ETHBridge} from "../bridge/interfaces/IL2ETHBridge.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact enxi.zys@antgroup.com
contract L2CoinBase is OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    address public l2EthBridge;

    receive() external payable {}

    constructor() {
        _disableInitializers();
    }

    function initialize(address _l2EthBridge) external initializer {
        require(_l2EthBridge != address(0), "L2CoinBase: l2EthBridge is zero address");
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        l2EthBridge = _l2EthBridge;
        emit Initliazed(_l2EthBridge);
    }

    // Withdrawal permission account
    mapping(address withdrawerAddress => bool) public isWithdrawer;

    // Whitelisted accounts on L1, to which withdrawals can be made
    mapping(address whiteAddress => bool) public whiteListOnL1;

    modifier onlyWithdrawer() {
        // @note In the decentralized mode, it should be only called by a list of validator.
        require(isWithdrawer[_msgSender()], "INVALID_PERMISSION : sender is not withdrawer");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    event SetL2EthBridge(address indexed l2EthBridge);

    event AddWithdrawer(address indexed newWithdrawer);

    event RemoveWithdrawer(address indexed oldWithdrawer);

    event AddWhiteAddress(address indexed whiteAddress);

    event RemoveWhiteAddress(address indexed whiteAddress);

    event CoinBaseWithdraw(address indexed _target, uint256 indexed amount);

    event Initliazed(address indexed l2EthBridge);

    function setL2EthBridge(address _newL2EthBridge) external whenPaused onlyOwner {
        require(_newL2EthBridge != address(0), "L2CoinBase: newL2EthBridge is zero address");
        l2EthBridge = _newL2EthBridge;
        emit SetL2EthBridge(_newL2EthBridge);
    }

    function addWithdrawer(address _newWithdrawer) external onlyOwner {
        isWithdrawer[_newWithdrawer] = true;

        emit AddWithdrawer(_newWithdrawer);
    }

    function removeWithdrawer(address _oldWithdrawer) external onlyOwner {
        isWithdrawer[_oldWithdrawer] = false;

        emit RemoveWithdrawer(_oldWithdrawer);
    }

    function addWhiteAddress(address _whiteAddress) external onlyOwner {
        whiteListOnL1[_whiteAddress] = true;

        emit AddWhiteAddress(_whiteAddress);
    }

    function removeWhiteAddress(address _whiteAddress) external onlyOwner {
        whiteListOnL1[_whiteAddress] = false;

        emit RemoveWhiteAddress(_whiteAddress);
    }

    function withdraw(address _target, uint256 _amount) public onlyWithdrawer whenNotPaused nonReentrant {
        require(whiteListOnL1[_target], "INVALID_PERMISSION : target is not receiver on L1");
        require(
            _amount <= address(this).balance,
            "INVALID_PERMISSION : withdraw amount must smaller than or equal to balance"
        );

        bytes memory message_ = abi.encodeCall(IL2ETHBridge.withdraw, (_target, _amount, 0, ""));
        (bool success_,) = l2EthBridge.call{value: _amount}(message_);
        require(success_, "withdraw failed in L2EthBridge");
        emit CoinBaseWithdraw(_target, _amount);
    }

    function withdrawAll(address _target) external onlyWithdrawer {
        withdraw(_target, address(this).balance);
    }
}
