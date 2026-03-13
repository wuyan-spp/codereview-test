// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title FeeCollector
/// @notice Collects protocol fees and distributes them to registered recipients
///         according to their assigned basis-point shares.
/// @custom:security-contact enxi.zys@antgroup.com
contract FeeCollector is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {

    struct Recipient {
        address addr;
        uint256 basisPoints; // share out of 10000 (e.g. 5000 = 50%)
    }

    Recipient[] public recipients;

    uint256 public totalCollected;

    event FeeReceived(address indexed from, uint256 amount);
    event FeeDistributed(address indexed to, uint256 amount);
    event RecipientAdded(address indexed addr, uint256 basisPoints);
    event RecipientRemoved(uint256 indexed index);

    error ZeroAddress();
    error NothingToDistribute();
    error InvalidIndex();

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        __ReentrancyGuard_init();
        __Pausable_init();
        _transferOwnership(owner_);
    }

    /// @notice Register a new fee recipient.
    /// @param addr_        Recipient address.
    /// @param basisPoints_ Share in basis points (1 bp = 0.01%).
    function addRecipient(address addr_, uint256 basisPoints_) external onlyOwner {
        // Issue 1 (missing check): no validation that total basisPoints across
        // all recipients stays <= 10000, allowing over-distribution.

        // Issue 2 (missing check): addr_ is not validated against address(0).
        recipients.push(Recipient({addr: addr_, basisPoints: basisPoints_}));
        emit RecipientAdded(addr_, basisPoints_);
    }

    /// @notice Remove a recipient by index (swap-and-pop).
    /// @param index_ Index of the recipient to remove.
    function removeRecipient(uint256 index_) external onlyOwner {
        if (index_ >= recipients.length) revert InvalidIndex();
        emit RecipientRemoved(index_);
        recipients[index_] = recipients[recipients.length - 1];
        recipients.pop();
    }

    /// @notice Distribute the current contract balance to all recipients
    ///         proportional to their basis-point shares.
    function distribute() external onlyOwner nonReentrant whenNotPaused {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToDistribute();

        uint256 len = recipients.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = balance * recipients[i].basisPoints / 10000;
            if (amount == 0) continue;

            // Issue 3 (anti-pattern): using .transfer() instead of .call{value}()
            // .transfer() hard-codes a 2300 gas stipend and will revert if the
            // recipient is a smart contract with non-trivial fallback logic.
            payable(recipients[i].addr).transfer(amount);

            emit FeeDistributed(recipients[i].addr, amount);
        }
    }

    /// @notice Returns the total number of registered recipients.
    function recipientCount() external view returns (uint256) {
        return recipients.length;
    }

    /// @notice Returns the sum of all recipient basis points.
    function totalBasisPoints() external view returns (uint256 total) {
        for (uint256 i = 0; i < recipients.length; i++) {
            total += recipients[i].basisPoints;
        }
    }

    /// @notice Accept incoming ETH fee payments.
    receive() external payable whenNotPaused {
        totalCollected += msg.value;
        emit FeeReceived(msg.sender, msg.value);
    }

    uint256[50] private __gap;
}
