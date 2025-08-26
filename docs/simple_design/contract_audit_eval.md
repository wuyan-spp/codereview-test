Jovay Contracts Audit Eval
==========


# Overview

The scope of this security audit encompasses smart contracts from two primary repositories: **jovay-sequencer** and **jovay**. The functional breakdown is as follows:

- jovay-sequencer: This repository contains the core system contracts that govern access control, rule configuration, system parameter settings, and staking.
- jovay: This repository contains the contracts that implement the platform's Rollup logic, cross-chain functionality, and TEE verification.

A detailed breakdown of the specific directories and their respective lines of code is provided below.

| Module | Contents | File Count | Pure Code Lines | Blank Lines | Comment Lines |
| --- | --- | --- | --- | --- | --- |
| **jovay-sequencer** | sequencer_contracts/sys_contract/artifact_src/solidity/permission_control.sol | 1 | 69 | 17 | 4 |
| **jovay-sequencer** | sequencer_contracts/sys_contract/artifact_src/solidity/rule_mng.sol | 1 | 318 | 68 | 23 |
| **jovay-sequencer** | sequencer_contracts/sys_contract/artifact_src/solidity/sys_chaincfg.sol | 1 | 87 | 18 | 1 |
| **jovay-sequencer** | sequencer_contracts/sys_contract/artifact_src/solidity/sys_staking.sol | 1 | 1,339 | 274 | 1,147 |
| **rollup** | rollup_contracts/contracts/common/ | 9 | 258 | 84 | 82 |
| **rollup** | rollup_contracts/contracts/L1/bridge/ | 6 | 121 | 38 | 91 |
| **rollup** | rollup_contracts/contracts/L1/core/ | 2 | 354 | 85 | 130 |
| **rollup** | rollup_contracts/contracts/L1/interfaces/ | 3 | 48 | 21 | 51 |
| **rollup** | rollup_contracts/contracts/L1/libraries/ | 4 | 113 | 27 | 101 |
| **rollup** | rollup_contracts/contracts/L1/tee_verifier/src/ | 5 | 568 | 85 | 51 |
| **rollup** | rollup_contracts/contracts/L2/ | 8 | 218 | 63 | 168 |
| **Total** | **-** | **41** | **3,493** | **780** | **1,849** |

# Details

https://github.com/jovaynetwork/jovay-contracts/

```
.
├── rollup_contracts/contracts
│ ├── common
│ │ ├── BridgeBase.sol
│ │ ├── ERC20Token.sol
│ │ ├── interfaces
│ │ │ ├── IBridgeBase.sol
│ │ │ ├── IERC20Token.sol
│ │ │ ├── IGasPriceOracle.sol
│ │ │ ├── IMailBoxBase.sol
│ │ │ └── ITokenBridge.sol
│ │ ├── MailBoxBase.sol
│ │ └── TokenBridge.sol
│ ├── L1
│ │ ├── bridge
│ │ │ ├── interfaces
│ │ │ │ ├── IL1BridgeProof.sol
│ │ │ │ ├── IL1ERC20Bridge.sol
│ │ │ │ └── IL1ETHBridge.sol
│ │ │ ├── L1BridgeProof.sol
│ │ │ ├── L1ERC20Bridge.sol
│ │ │ └── L1ETHBridge.sol
│ │ ├── core
│ │ │ ├── L1Mailbox.sol
│ │ │ └── Rollup.sol
│ │ ├── interfaces
│ │ │ ├── IL1Mailbox.sol
│ │ │ ├── IL1MailQueue.sol
│ │ │ └── IRollup.sol
│ │ ├── libraries
│ │ │ ├── codec
│ │ │ │ └── BatchHeaderCodec.sol
│ │ │ └── verifier
│ │ │     ├── ITeeRollupVerifier.sol
│ │ │     ├── IZkRollupVerifier.sol
│ │ │     └── WithdrawTrieVerifier.sol
│ │ └── tee_verifier
│ │     ├── src
│ │     │ ├── DcapAttestationRouter.sol
│ │     │ ├── interfaces
│ │     │ │ └── ITeeRollupVerifier.sol
│ │     │ ├── MeasurementDao.sol
│ │     │ ├── TEECacheVerifier.sol
│ │     │ └── TEEVerifierProxy.sol
│ │     ├── lib
│ │     │ ├── automata-dcap-attestation/evm/contracts/verifiers/V5QuoteVerifier.sol
│ │     │ ├── automata-dcap-attestation/evm/contracts/PCCSRouter.sol
│ └── L2
│     ├── bridge
│     │ ├── interfaces
│     │ │ ├── IL2ERC20Bridge.sol
│     │ │ └── IL2ETHBridge.sol
│     │ ├── L2ERC20Bridge.sol
│     │ └── L2ETHBridge.sol
│     ├── core
│     │ └── L2Mailbox.sol
│     ├── interfaces
│     │ ├── IL2Mailbox.sol
│     │ └── IL2MailQueue.sol
│     └── libraries
│         └── common
│             └── AppendOnlyMerkleTree.sol

└── sequencer_contracts/aldaba-ng
    └── sys_contract
        └── artifact_src
            └── solidity
                ├── permission_control.sol
                ├── rule_mng.sol
                ├── sys_chaincfg.sol
                ├── sys_staking.sol
                
```
