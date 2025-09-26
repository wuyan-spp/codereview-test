// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @custom:security-contact liyuwen.lyw@antgroup.com
contract ChainCfg {
    struct Config {
        string key;
        string value;
    }

    struct ConfigCheckpoint {
        uint64 blockNum;
        uint64 effectiveBlockNum;
        Config[] configs;
    }

    ConfigCheckpoint[] private configCps;

    event ConfigUpdate(uint64 indexed blockNum, uint64 indexed effectiveBlockNum, string[] keys, string[] values);

    address public rootSys;
    address public constant SYS_STAKING = 0x4100000000000000000000000000000000000000;
    address public constant INTRINSIC_SYS = 0x1111111111111111111111111111111111111111;

    modifier onlyOwner() {
        require(msg.sender == rootSys || msg.sender == SYS_STAKING || msg.sender == INTRINSIC_SYS, "Not owner");
        _;
    }

    function changeSys(address _newOwner) public onlyOwner {
        rootSys = _newOwner;
    }

    function get_config(string memory key) public view returns (string memory) {
        // Check configCps length
        if (configCps.length == 0) {
            return "";
        }

        if (configCps.length == 1) {
            // Only have effective config
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Check if block number has reached effective block
            // Config will be inited in genesis block and will be effective at block 0, so this if block
            // will not be entered. This block is write for Defensive Programming.
            if (block.number < effectiveCp.effectiveBlockNum) {
                return "";
            }

            // Search for config value
            for (uint256 i = 0; i < effectiveCp.configs.length; i++) {
                Config storage conf = effectiveCp.configs[i];
                if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                    return conf.value;
                }
            }
            return "";
        }

        // Have both effective and latest configs
        ConfigCheckpoint storage latestCp = configCps[1];

        // Check if latest config is effective
        if (block.number >= latestCp.effectiveBlockNum) {
            // Latest config is effective, use it
            for (uint256 i = 0; i < latestCp.configs.length; i++) {
                Config storage conf = latestCp.configs[i];
                if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                    return conf.value;
                }
            }
        } else {
            // Latest config not effective, use effective config
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Check if effective config is actually effective
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

    function get_configs() public view returns (Config[] memory) {
        // Check configCps length
        if (configCps.length == 0) {
            Config[] memory emptyConfigs;
            return emptyConfigs;
        }

        if (configCps.length == 1) {
            // Only have effective config
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Config will be inited in genesis block and will be effective at block 0, so this if block
            // will not be entered. This block is write for Defensive Programming.
            if (block.number < effectiveCp.effectiveBlockNum) {
                Config[] memory emptyConfigs;
                return emptyConfigs;
            }

            return effectiveCp.configs;
        }

        // Have both effective and latest configs
        ConfigCheckpoint storage latestCp = configCps[1];

        // Check if latest config is effective
        if (block.number >= latestCp.effectiveBlockNum) {
            return latestCp.configs;
        } else {
            // Latest config not effective, use effective config
            ConfigCheckpoint storage effectiveCp = configCps[0];

            // Check if effective config is actually effective
            if (block.number >= effectiveCp.effectiveBlockNum) {
                return effectiveCp.configs;
            } else {
                // Config will be inited in genesis block and will be effective at block 0, so this else block
                // will not be entered. This block is write for Defensive Programming.
                Config[] memory emptyConfigs;
                return emptyConfigs;
            }
        }
    }

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

    function _buildMergedConfig(Config[] memory baseConfigs, string[] memory keys, string[] memory values)
        private
        pure
        returns (Config[] memory)
    {
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
