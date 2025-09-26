// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Panic.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SysChainCfg Interface
/// @author Jovay Network
/// @custom:security-contact liyuwen.lyw@antgroup.com
/// @notice Interface for the system configuration contract (`ChainCfg`).
/// This interface defines the functions that can be called on the `ChainCfg` contract
/// to manage and retrieve chain-wide configuration parameters.
interface SysChainCfg {
    /// @notice Sets or updates one or more configuration parameters.
    /// @param keys An array of configuration keys to update.
    /// @param values An array of corresponding values.
    function set_config(string[] calldata keys, string[] calldata values) external;

    /// @notice Retrieves the value of a configuration parameter for a given key.
    /// @param key The key of the configuration parameter to retrieve.
    /// @return The value of the configuration parameter.
    function get_config(string calldata key) external view returns (string memory);
}

/// @title DPoSValidatorManager
/// @author Jovay Network
/// @notice This contract manages the set of validators.
/// It handles validator registration, epoch transitions.
contract DPoSValidatorManager is ReentrancyGuard {
    /// @notice Represents a validator in the DPoS system.
    struct Validator {
        string description; // A human-readable description of the validator.
        string publicKey; // The validator's public key for signing.
        string publicKeyPop; // Proof of possession for the public key.
        string blsPublicKey; // The validator's BLS public key for consensus.
        string blsPublicKeyPop; // Proof of possession for the BLS public key.
        string endpoint; // The network endpoint of the validator.
        uint8 status; // The current status of the validator.
        bytes32 poolId; // A unique identifier for the validator's staking pool.
        uint256 totalStake; // The total amount of stake delegated to this validator.
        address owner; // The address of the validator's owner.
        uint256 stakeSnapshot; // A snapshot of the validator's stake at a specific epoch.
        uint256 pendingWithdrawStake; // The amount of stake pending withdrawal.
        uint8 pendingWithdrawWindow; // The window during which a withdrawal is pending.
    }

    /// @notice A mapping from a validator's pool ID to their `Validator` struct.
    mapping(bytes32 => Validator) public validators;
    /// @notice An array of pool IDs for all currently active validators.
    bytes32[] public activePoolIds;
    /// @notice An array of pool IDs for validators that are pending to be added.
    bytes32[] public pendingAddPoolIds;
    /// @notice An array of pool IDs for validators that are pending to exit.
    bytes32[] public pendingExitPoolIds;

    /// @notice The current epoch number. An epoch is a period of time during which the validator set is fixed.
    uint256 public currentEpoch;
    /// @notice The total stake across all validators in the system.
    uint256 public totalStake;

    /// @notice The constant address for the system chain configuration contract.
    address public constant SYS_CHAIN_CFG = 0x3100000000000000000000000000000000000000;
    /// @notice The special system address.
    address public constant INTRINSIC_SYS = 0x1111111111111111111111111111111111111111;

    /// @notice Emitted when a new epoch begins.
    /// @param epochNumber The number of the new epoch.
    /// @param blockNumber The block number at which the epoch change occurred.
    /// @param timestamp The timestamp of the block at which the epoch change occurred.
    /// @param totalStake The total stake in the system at the start of the new epoch.
    /// @param activeValidators The list of active validator pool IDs for the new epoch.
    event EpochChange(
        uint256 indexed epochNumber,
        uint256 indexed blockNumber,
        uint256 timestamp,
        uint256 totalStake,
        bytes32[] activeValidators
    );

    /// @notice Error returned when a function is called by an address that is not the owner.
    error NotOwner();

    /// @notice Modifier to restrict function access to the `INTRINSIC_SYS` address.
    /// @dev Throws if the caller is not the `INTRINSIC_SYS`.
    modifier onlyOwner() {
        if (msg.sender != INTRINSIC_SYS) revert NotOwner();
        _;
    }

    /// @notice Advances the system to a new epoch.
    /// @dev This function can only be called by the `INTRINSIC_SYS` address.
    /// It updates the epoch-related information in the `SysChainCfg` contract and emits an `EpochChange` event.
    function advanceEpoch() external onlyOwner {
        setChainEpochBlock();
        currentEpoch++;

        emit EpochChange(currentEpoch, block.number, block.timestamp, totalStake, activePoolIds);
    }

    /// @notice Checks if a given element is present in an array of `bytes32`.
    /// @param array The array to search in.
    /// @param element The element to search for.
    /// @return `true` if the element is found, `false` otherwise.
    function isArrayContains(bytes32[] memory array, bytes32 element) private pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return true;
            }
        }
        return false;
    }

    /// @notice Internal function to update the epoch start block and timestamp in the `SysChainCfg` contract.
    function setChainEpochBlock() private {
        SysChainCfg sys_chain_cfg = SysChainCfg(SYS_CHAIN_CFG);
        string[] memory keys = new string[](2);
        string[] memory values = new string[](2);

        // Prepare the key-value pair for the epoch start block number.
        string memory epoch_num_key = "chain.epoch_start_block";
        string memory epoch_num_value = Strings.toString(block.number);
        keys[0] = epoch_num_key;
        values[0] = epoch_num_value;

        // Prepare the key-value pair for the epoch start timestamp.
        string memory epoch_time_key = "chain.epoch_start_timestamp";
        string memory epoch_time_value = Strings.toString(block.timestamp);
        keys[1] = epoch_time_key;
        values[1] = epoch_time_value;

        // Call the set_config function on the SysChainCfg contract to update the configuration.
        sys_chain_cfg.set_config(keys, values);
    }
}