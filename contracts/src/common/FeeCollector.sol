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

    /// @dev 10 000 basis points = 100 %.
    uint256 private constant BP_DIVISOR = 10_000;

    struct Recipient {
        address addr;
        uint256 basisPoints; // share out of BP_DIVISOR (e.g. 5000 = 50%)
    }

    Recipient[] public recipients;

    uint256 public totalCollected;

    event FeeReceived(address indexed from, uint256 amount);
    event FeeDistributed(address indexed to, uint256 amount);
    event RecipientAdded(address indexed addr, uint256 basisPoints);
    event RecipientRemoved(uint256 indexed index);

    error ZeroAddress();
    error ZeroBasisPoints();
    error BasisPointsExceedMax();
    error NothingToDistribute();
    error InvalidIndex();
    error TransferFailed();

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
    /// @param addr_        Recipient address (must not be zero).
    /// @param basisPoints_ Share in basis points (1 bp = 0.01%); sum across all
    ///                     recipients must not exceed BP_DIVISOR (10 000).
    function addRecipient(address addr_, uint256 basisPoints_) external onlyOwner {
        if (addr_ == address(0)) revert ZeroAddress();
        if (basisPoints_ == 0) revert ZeroBasisPoints();
        if (totalBasisPoints() + basisPoints_ > BP_DIVISOR) revert BasisPointsExceedMax();

        recipients.push(Recipient({addr: addr_, basisPoints: basisPoints_}));
        emit RecipientAdded(addr_, basisPoints_);
    }

    /// @notice Remove a recipient by index (swap-and-pop).
    /// @param index_ Index of the recipient to remove.
    function removeRecipient(uint256 index_) external onlyOwner {
        if (index_ >= recipients.length) revert InvalidIndex();
        recipients[index_] = recipients[recipients.length - 1];
        recipients.pop();
        emit RecipientRemoved(index_);
    }

    /// @notice Distribute the current contract balance to all recipients
    ///         proportional to their basis-point shares.
    function distribute() external onlyOwner nonReentrant whenNotPaused {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NothingToDistribute();

        uint256 len = recipients.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 amount = balance * recipients[i].basisPoints / BP_DIVISOR;
            if (amount == 0) continue;

            // Use .call{value}() to avoid the 2300-gas stipend imposed by
            // .transfer(), which would revert for contract recipients with
            // non-trivial receive() logic (e.g. multi-sig wallets).
            (bool ok,) = payable(recipients[i].addr).call{value: amount}("");
            if (!ok) revert TransferFailed();

            emit FeeDistributed(recipients[i].addr, amount);
        }
    }

    /// @notice Returns the total number of registered recipients.
    function recipientCount() external view returns (uint256) {
        return recipients.length;
    }

    /// @notice Returns the sum of all recipient basis points.
    /// @return total Sum of basis points across all registered recipients.
    function totalBasisPoints() public view returns (uint256 total) {
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
