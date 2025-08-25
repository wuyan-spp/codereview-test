require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */

const anvilPrivateKey = '';
const privateKey = '';
const ethprivateKey = '';

module.exports = {
  solidity: "0.8.28",
  networks: {
    anvil: {
      url: '', // 输入您的RPC URL
      chainId: 31337, // (hex: 0x504),
      accounts: [anvilPrivateKey],
      blockGasLimit: 30000000
    },
    moonbase: {
      url: '', // 输入您的RPC URL
      chainId: 3503995874084926, // (hex: 0x504),
      accounts: [privateKey],
      blockGasLimit: 100000000
    },
    eth: {
      url: '', // 输入您的RPC URL
      chainId: 3151908, // (hex: 0x504),
      accounts: [ethprivateKey],
    },
  },
  upgrades: {
    unsafeAllow: ["constructor"], // 允许使用构造函数
  },
  paths: {
    sources:"contracts/L1/core"
  }
};
