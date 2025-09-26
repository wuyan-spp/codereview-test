// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @title ChainCfg
/// @author Jovay Network
/// @custom:security-contact liyuwen.lyw@antgroup.com
/// @notice This contract manages chain configuration parameters.
/// It supports a two-stage configuration update mechanism (pending and effective)
/// to ensure that configuration changes take effect at a specific future block.
contract ChainCfg {
    /// @notice Represents a single configuration entry as a key-value pair.
    struct Config {
        string key;
        string value;
    }

    /// @notice A checkpoint for a set of configurations, including the block number
    /// when it was created and when it becomes effective.
    struct ConfigCheckpoint {
        uint64 blockNum; // The block number when this checkpoint was created.
        uint64 effectiveBlockNum; // The block number from which this checkpoint's config is effective.
        Config[] configs; // The array of configuration entries for this checkpoint.
    }

    // An array to store configuration checkpoints. It holds at most two checkpoints:
    // - configCps[0]: The currently effective configuration.
    // - configCps[1]: The pending configuration that will become effective in a future block.
    ConfigCheckpoint[] private configCps;

    /// @notice Emitted when a configuration update is proposed.
    /// @param blockNum The block number when the update was proposed.
    /// @param effectiveBlockNum The block number when the new configuration will become effective.
    /// @param keys The keys of the configuration parameters being updated.
    /// @param values The new values for the corresponding keys.
    event ConfigUpdate(uint64 indexed blockNum, uint64 indexed effectiveBlockNum, string[] keys, string[] values);

    /// @notice The address of the root system owner, with privileges to change configurations.
    address public rootSys;
    /// @notice The constant address for the system staking contract.
    address public constant SYS_STAKING = 0x4100000000000000000000000000000000000000;
    /// @notice A special system address with owner-like privileges.
    address public constant INTRINSIC_SYS = 0x1111111111111111111111111111111111111111;

    /// @notice Modifier to restrict function access to authorized system addresses.
    /// @dev Throws if the caller is not the `rootSys`, `SYS_STAKING`, or `INTRINSIC_SYS`.
    modifier onlyOwner() {
        require(msg.sender == rootSys || msg.sender == SYS_STAKING || msg.sender == INTRINSIC_SYS, "Not owner");
        _;
    }

    /// @notice Changes the root system owner address.
    /// @param _newOwner The address of the new owner.
    function changeSys(address _newOwner) public onlyOwner {
        rootSys = _newOwner;
    }

    /// @notice Retrieves the value of a configuration parameter for a given key.
    /// @param key The key of the configuration parameter to retrieve.
    /// @return value The value of the configuration parameter. Returns an empty string if the key is not found or no configuration is effective.
    function get_config(string memory key) public view returns (string memory) {
        // If there are no configuration checkpoints, no config is set.
        if (configCps.length == 0) {
            return "";
        }

        if (configCps.length == 1) {
            // Only one checkpoint exists, which is the currently effective one.
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // This check is for defensive programming. In practice, the initial config is effective from block 0.
            if (block.number < effectiveCp.effectiveBlockNum) {
                return "";
            }

            // Search for the config value by key.
            for (uint256 i = 0; i < effectiveCp.configs.length; i++) {
                Config storage conf = effectiveCp.configs[i];
                if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                    return conf.value;
                }
            }
            return "";
        }

        // Two checkpoints exist: effective (configCps[0]) and pending (configCps[1]).
        ConfigCheckpoint storage latestCp = configCps[1];

        // Check if the pending configuration has become effective.
        if (block.number >= latestCp.effectiveBlockNum) {
            // The pending config is now effective, search within it.
            for (uint256 i = 0; i < latestCp.configs.length; i++) {
                Config storage conf = latestCp.configs[i];
                if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                    return conf.value;
                }
            }
        } else {
            // The pending config is not yet effective, so use the current effective one.
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Check if the current effective config is actually active.
            if (block.number >= effectiveCp.effectiveBlockNum) {
                for (uint256 i = 0; i < effectiveCp.configs.length; i++) {
                    Config storage conf = effectiveCp.configs[i];
                    if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                        return conf.value;
                    }
                }
            }
        }

        return "";
    }

    /// @notice Retrieves all current effective configuration parameters.
    /// @return An array of `Config` structs representing the current key-value pairs.
    function get_configs() public view returns (Config[] memory) {
        // If there are no configuration checkpoints, return an empty array.
        if (configCps.length == 0) {
            Config[] memory emptyConfigs;
            return emptyConfigs;
        }

        if (configCps.length == 1) {
            // Only one (effective) checkpoint exists.
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Defensive check. The initial config should be effective from block 0.
            if (block.number < effectiveCp.effectiveBlockNum) {
                Config[] memory emptyConfigs;
                return emptyConfigs;
            }

            return effectiveCp.configs;
        }

        // Two checkpoints exist: effective and pending.
        ConfigCheckpoint storage latestCp = configCps[1];

        // Determine which checkpoint is currently active based on the block number.
        if (block.number >= latestCp.effectiveBlockNum) {
            return latestCp.configs;
        } else {
            // The pending config is not yet effective, use the current effective one.
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Defensive check.
            if (block.number >= effectiveCp.effectiveBlockNum) {
                return effectiveCp.configs;
            } else {
                // This case should not be reached in practice.
                Config[] memory emptyConfigs;
                return emptyConfigs;
            }
        }
    }

    /// @notice Sets or updates one or more configuration parameters.
    /// @dev This creates a new pending configuration checkpoint that will become effective in a future block.
    /// @param keys An array of configuration keys to update.
    /// @param values An array of corresponding values.
    function set_config(string[] calldata keys, string[] calldata values) external onlyOwner {
        require(keys.length == values.length, "KVs are not match");
        // Config will be inited in genesis block and will be effective at block 0, so this if block
        // will not be entered. This block is write for Defensive Programming.
        if (configCps.length == 0) {
            // First time initialization: create empty effective config
            configCps.push();
            ConfigCheckpoint storage effectiveCp = configCps[0];
            effectiveCp.blockNum = 0;
            effectiveCp.effectiveBlockNum = 0;
            // effectiveCp.configs remains empty
        }

        if (configCps.length == 1) {
            // Only have effective config, create pending config
            configCps.push();
            ConfigCheckpoint storage pendingCp = configCps[1];
            pendingCp.blockNum = uint64(block.number);
            pendingCp.effectiveBlockNum = uint64(block.number + 1);

            // Build merged configuration using helper function
            Config[] memory mergedConfigs = _buildMergedConfig(configCps[0].configs, keys, values);

            // Populate pending config
            for (uint256 i = 0; i < mergedConfigs.length; i++) {
                pendingCp.configs.push(mergedConfigs[i]);
            }

            emit ConfigUpdate(uint64(block.number), uint64(block.number + 1), keys, values);
            return;
        }

        // Have both effective and pending configs
        ConfigCheckpoint storage latestCp = configCps[1];
        // Build merged configuration using helper function
        Config[] memory baseConfigs = latestCp.configs;
        Config[] memory mergedConfigs = _buildMergedConfig(latestCp.configs, keys, values);
        
        if (block.number >= latestCp.effectiveBlockNum) {
            // Latest config has become effective, move it to effective config
            configCps[0] = latestCp;

            // Create new pending config
            latestCp.blockNum = uint64(block.number);
            latestCp.effectiveBlockNum = uint64(block.number + 1);
        }

        // Clear and populate storage
        delete latestCp.configs;
        for (uint256 i = 0; i < mergedConfigs.length; i++) {
            latestCp.configs.push(mergedConfigs[i]);
        }

        emit ConfigUpdate(uint64(block.number), uint64(block.number + 1), keys, values);
    }

    /// @notice Internal pure function to merge a base configuration with new key-value pairs.
    /// @param baseConfigs The existing configuration array.
    /// @param keys The new or updated keys.
    /// @param values The new or updated values.
    /// @return A new array of `Config` structs containing the merged configuration.
    function _buildMergedConfig(Config[] memory baseConfigs, string[] memory keys, string[] memory values)
        private
        pure
        returns (Config[] memory)
    {
        // Pre-allocate a new array with maximum possible size.
        Config[] memory newConfigs = new Config[](baseConfigs.length + keys.length);
        uint256 newLength = 0;

        // Preserve unmodified existing configurations
        for (uint256 i = 0; i < baseConfigs.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < keys.length; j++) {
                if (keccak256(abi.encodePacked(baseConfigs[i].key)) == keccak256(abi.encodePacked(keys[j]))) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                newConfigs[newLength] = baseConfigs[i];
                newLength++;
            }
        }

        // Add new or updated configurations
        for (uint256 i = 0; i < keys.length; i++) {
            newConfigs[newLength] = Config(keys[i], values[i]);
            newLength++;
        }

        // Resize array
        assembly {
            mstore(newConfigs, newLength)
        }

        return newConfigs;
    }
}