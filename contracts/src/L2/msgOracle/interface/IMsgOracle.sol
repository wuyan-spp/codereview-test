// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IMsgOracle {
    struct VoteData {
        address sender;
        address target;
        uint256 value;
        uint256 nonce;
        bytes message;
    }

    event VoteRecorded(address indexed voter, uint256 nonce, bytes32 indexed msgHash);
    event MessageApproved(bytes32 indexed msgHash, uint256 nonce);
    event MultipleMessageApproved(uint256 count);
    event VoterAdded(address indexed voter);
    event VoterRemoved(address indexed voter);
    event ThresholdUpdated(uint256 newThreshold);

    function getVoters() external view returns (address[] memory);
    function isVoter(address account_) external view returns (bool);
    function getMsgHashes(uint256 nonce_) external view returns (bytes32[] memory);

    function vote(VoteData[] calldata votes_) external;
    function approve(uint256 maxApproveCount_) external;

    function addVoter(address voter_) external;
    function removeVoter(address voter_) external;
    function setThreshold(uint256 threshold_) external;
}
