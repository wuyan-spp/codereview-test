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
        if (configCps.length != 0) {
            for (uint256 i = 0; i < configCps[configCps.length - 1].configs.length; i++) {
                Config storage conf = configCps[configCps.length - 1].configs[i];
                if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked(conf.key))) {
                    return conf.value;
                }
            }
        }
        return "";
    }

    function get_configs() public view returns (Config[] memory) {
        if (configCps.length != 0) {
            return configCps[configCps.length - 1].configs;
        }
        Config[] memory configs;
        return configs;
    }

    function set_config(string[] memory keys, string[] memory values) external onlyOwner {
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
        Config[] memory baseConfigs = (block.number >= latestCp.effectiveBlockNum) ? configCps[0].configs : latestCp.configs;
        Config[] memory mergedConfigs = _buildMergedConfig(baseConfigs, keys, values);
        
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
    
    function _buildMergedConfig(Config[] memory baseConfigs, string[] memory keys, string[] memory values) private pure returns (Config[] memory) {
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