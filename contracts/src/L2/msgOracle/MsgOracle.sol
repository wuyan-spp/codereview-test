// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IL2Mailbox} from "../interfaces/IL2Mailbox.sol";
import {IMsgOracle} from "./interface/IMsgOracle.sol";

contract MsgOracle is Initializable, OwnableUpgradeable, PausableUpgradeable, IMsgOracle {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.AddressSet private voters;
    uint256 public threshold;
    IL2Mailbox public l2Mailbox;
    uint256 public nextApproveNonce;

    mapping(bytes32 => VoteData) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(bytes32 => uint256) public voteCounts;
    mapping(uint256 => EnumerableSet.Bytes32Set) private nonceToMsgHashes;

    function initialize(
        address[] memory voters_,
        uint256 threshold_,
        address l2Mailbox_,
        uint256 nextApproveNonce_
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        require(voters_.length > 0, "No voters provided");
        for (uint256 i = 0; i < voters_.length; ++i) {
            require(voters_[i] != address(0), "Invalid voter address");
            voters.add(voters_[i]);
        }

        require(threshold_ > 0 && threshold_ <= voters.length(), "Invalid threshold");
        threshold = threshold_;
        require(l2Mailbox_ != address(0) && l2Mailbox_.code.length > 0, "Invalid L2Mailbox address");
        l2Mailbox = IL2Mailbox(l2Mailbox_);

        nextApproveNonce = nextApproveNonce_;
    }

    function vote(VoteData[] calldata votes_) external override whenNotPaused{
        require(voters.contains(msg.sender), "Not a valid voter");
        uint256 votesLen = votes_.length;
        require(votesLen <= 100, "Votes length exceeds 100");

        for (uint256 i = 0; i < votesLen; ++i) {
            VoteData memory v = votes_[i];
            bytes32 msgHash = keccak256(abi.encode(v.sender, v.target, v.value, v.nonce, v.message));
            if (hasVoted[v.nonce][msg.sender]){
                continue;
            }
            hasVoted[v.nonce][msg.sender] = true;
            nonceToMsgHashes[v.nonce].add(msgHash);
            voteCounts[msgHash]++;
            votes[msgHash] = v;

            emit VoteRecorded(msg.sender, v.nonce, msgHash);
        }
    }

    function approve(uint256 maxApproveCount_) external override {
        require(maxApproveCount_ > 0 && maxApproveCount_ <= 100, "Invalid maxApproveCount");

        uint256 processed = 0;
        while (processed < maxApproveCount_) {
            uint256 currentNonce = nextApproveNonce;
            EnumerableSet.Bytes32Set storage msgHashes = nonceToMsgHashes[currentNonce];

            if (msgHashes.length() == 0) {
                break;
            }

            bytes32 maxVotedHash;
            uint256 maxVotes = 0;
            for (uint256 i = 0; i < msgHashes.length(); ++i) {
                bytes32 hash = msgHashes.at(i);
                uint256 count = voteCounts[hash];
                if (count > maxVotes) {
                    maxVotes = count;
                    maxVotedHash = hash;
                }
            }

            if (maxVotes >= threshold) {
                VoteData memory voteData = votes[maxVotedHash];
                l2Mailbox.approveMsg(
                    voteData.sender,
                    voteData.target,
                    voteData.value,
                    voteData.nonce,
                    voteData.message
                );
                nextApproveNonce++;
                processed++;
                emit MessageApproved(maxVotedHash, voteData.nonce);
            } else {
                break;
            }
        }
        emit MultipleMessageApproved(processed);
    }

    function getVoters() public view override returns (address[] memory) {
        return voters.values();
    }

    function isVoter(address account_) public view override returns (bool) {
        return voters.contains(account_);
    }

    function getMsgHashes(uint256 nonce_) public view returns (bytes32[] memory) {
        return nonceToMsgHashes[nonce_].values();
    }

    // Owner functions for managing the oracle
    function addVoter(address voter_) external onlyOwner {
        require(voter_ != address(0), "Invalid voter address");
        require(!voters.contains(voter_), "Already a voter");
        voters.add(voter_);
        emit VoterAdded(voter_);
    }

    function removeVoter(address voter_) external onlyOwner {
        require(voters.contains(voter_), "Not a voter");
        require(voters.length() > 1, "Cannot remove last voter");
        require(threshold <= voters.length() - 1, "Threshold too high");
        voters.remove(voter_);
        emit VoterRemoved(voter_);
    }

    function setThreshold(uint256 threshold_) external onlyOwner {
        require(threshold_ > 0 && threshold_ <= voters.length(), "Invalid threshold");
        threshold = threshold_;
        emit ThresholdUpdated(threshold_);
    }

    // Pausable functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

