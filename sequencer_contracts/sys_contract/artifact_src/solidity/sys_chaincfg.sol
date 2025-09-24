// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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


    ConfigCheckpoint[] configCps;

    event ConfigUpdate(uint64 indexed blockNum, uint64 indexed effectiveBlockNum, string[] keys, string[] values);
    
    address public rootSys;
    address public constant sysStaking = 0x4100000000000000000000000000000000000000;
    address public constant intrinsicSys = 0x1111111111111111111111111111111111111111;

    constructor() {
    }

    modifier onlyOwner() {
        require(msg.sender == rootSys || msg.sender == sysStaking || msg.sender == intrinsicSys, "Not owner");
        _;
    }

    function changeSys(address _newOwner)
        public
        onlyOwner
    {
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

    function set_config(string[] memory keys, string[] memory values) external onlyOwner {
        require(keys.length == values.length, "KVs are not match");
        if (configCps.length == 3) {
            delete configCps[0];
            for (uint256 i = 1; i < configCps.length; i++) {
                configCps[i - 1] = configCps[i];
            }
            configCps.pop(); 
        }

        uint256 old_config_cps_number = configCps.length;

        ConfigCheckpoint storage cfgCp = configCps.push();
        cfgCp.blockNum = uint64(block.number);
        cfgCp.effectiveBlockNum = uint64(block.number + 1);

        if (old_config_cps_number != 0) {
            require(configCps[configCps.length - 2].effectiveBlockNum <= block.number, "INVALID_STATE");

            for (uint256 i = 0; i < configCps[configCps.length - 2].configs.length; i++) {
                Config storage conf = configCps[configCps.length - 2].configs[i];
                bool found = false;
                for (uint256 j = 0; j < keys.length; j++) {
                    if (keccak256(abi.encodePacked(conf.key)) == keccak256(abi.encodePacked(keys[j]))) {
                        found = true; 
                        break;
                    }
                }
                if (!found) {
                    cfgCp.configs.push(Config({
                        key: conf.key,
                        value: conf.value
                    }));
                }
            }
        }

        for (uint256 i = 0; i < keys.length; i++) {
            cfgCp.configs.push(Config({
                key: keys[i],
                value: values[i]
            }));
        }

        emit ConfigUpdate(uint64(block.number), uint64(block.number + 1), keys, values);
    }
}