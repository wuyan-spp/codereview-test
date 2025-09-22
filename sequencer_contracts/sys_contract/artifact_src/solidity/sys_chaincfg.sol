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
        // Initialize array with one element if empty
        if (configCps.length == 0) {
            configCps.push();
        }
        
        ConfigCheckpoint storage cfgCp = configCps[0];
        cfgCp.blockNum = uint64(block.number);
        cfgCp.effectiveBlockNum = uint64(block.number + 1);
        
        // Preserve existing configurations
        Config[] memory oldConfigs = cfgCp.configs;
        
        // Clear existing configurations and refill
        delete cfgCp.configs;
        
        // Preserve unmodified existing configurations
        for (uint256 i = 0; i < oldConfigs.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < keys.length; j++) {
                if (keccak256(abi.encodePacked(oldConfigs[i].key)) == keccak256(abi.encodePacked(keys[j]))) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                cfgCp.configs.push(oldConfigs[i]);
            }
        }
        
        // Add new or updated configurations
        for (uint256 i = 0; i < keys.length; i++) {
            cfgCp.configs.push(Config({
                key: keys[i],
                value: values[i]
            }));
        }

        emit ConfigUpdate(uint64(block.number), uint64(block.number + 1), keys, values);
    }
}