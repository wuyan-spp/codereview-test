// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MsgOracle} from "../src/L2/msgOracle/MsgOracle.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IMsgOracle} from "../src/L2/msgOracle/interface/IMsgOracle.sol";

contract MockL2Mailbox {
    function approveMsg(
        address sender,
        address target,
        uint256 value,
        uint256 nonce,
        bytes calldata message
    ) external {}
}

contract MsgOracleTest is Test {
    MsgOracle public oracle;
    MockL2Mailbox public mockMailbox;
    
    address[] public voters;
    uint256 public threshold = 2;
    address public constant VOTER1 = address(0x1);
    address public constant VOTER2 = address(0x2);
    address public constant VOTER3 = address(0x3);
    address public constant NON_VOTER = address(0x4);

    function setUp() public {
        voters.push(VOTER1);
        voters.push(VOTER2);
        voters.push(VOTER3);
        
        mockMailbox = new MockL2Mailbox();
        
        // Deploy implementation
        MsgOracle implementation = new MsgOracle();


        //Test small threshold
        bytes memory initData_with_small_threshold = abi.encodeWithSelector(
            MsgOracle.initialize.selector,
            voters,
            1,
            address(mockMailbox),
            0
        );
        vm.expectRevert("Invalid threshold");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData_with_small_threshold
        );


        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            MsgOracle.initialize.selector,
            voters,
            threshold,
            address(mockMailbox),
            0
        );
        
        // Deploy proxy
        proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        oracle = MsgOracle(address(proxy));
    }

    function testInitialize() public {
        assertEq(oracle.threshold(), threshold);
        assertEq(address(oracle.l2Mailbox()), address(mockMailbox));
        assertEq(oracle.nextApproveNonce(), 0);
        assertEq(oracle.owner(), address(this));
        
        address[] memory storedVoters = oracle.getVoters();
        assertEq(storedVoters.length, voters.length);
        for (uint i = 0; i < voters.length; i++) {
            assertTrue(oracle.isVoter(voters[i]));
        }
    }

    // test: normal vote
    function testVote() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        // first vote from VOTER1
        vm.startPrank(VOTER1);
        oracle.vote(voteData);
        vm.stopPrank();

        bytes32 msgHash = keccak256(abi.encode(
            voteData[0].sender,
            voteData[0].target,
            voteData[0].value,
            voteData[0].nonce,
            voteData[0].message
        ));

        // check vote record
        assertEq(oracle.voteCounts(msgHash), 1);
        assertTrue(oracle.hasVoted(voteData[0].nonce, VOTER1));
        
        // second vote from VOTER2
        vm.startPrank(VOTER2);
        oracle.vote(voteData);
        vm.stopPrank();
        assertEq(oracle.voteCounts(msgHash), 2);
    }

    // test: non voter can not vote
    function testNonVoterCannotVote() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        vm.expectRevert("Not a valid voter");
        vm.startPrank(NON_VOTER);
        oracle.vote(voteData);
        vm.stopPrank();
    }

    // test: vote with same nonce
    function testCanVoteTwice() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });
        //first vote
        vm.startPrank(VOTER1);
        oracle.vote(voteData);
        vm.stopPrank();

        //vote repeatedly
        vm.startPrank(VOTER1);
        oracle.vote(voteData);

        bytes32 msgHash = keccak256(abi.encode(
                voteData[0].sender,
                voteData[0].target,
                voteData[0].value,
                voteData[0].nonce,
                voteData[0].message
            ));

        // check vote record
        assertEq(oracle.voteCounts(msgHash), 1);

        vm.stopPrank();
    }

    // test: normal approve
    function testApprove() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        // two voters vote
        vm.startPrank(VOTER1);
        oracle.vote(voteData);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voteData);
        vm.stopPrank();

        bytes32 msgHash = keccak256(abi.encode(
            voteData[0].sender,
            voteData[0].target,
            voteData[0].value,
            voteData[0].nonce,
            voteData[0].message
        ));
        
        // 验证邮箱调用
        vm.mockCall(
            address(mockMailbox),
            abi.encodeWithSelector(
                MockL2Mailbox.approveMsg.selector,
                voteData[0].sender,
                voteData[0].target,
                voteData[0].value,
                voteData[0].nonce,
                voteData[0].message
            ),
            ""
        );
        
        oracle.approve(1);
        assertEq(oracle.nextApproveNonce(), 1);
    }

    // test: can not approve below threshold
    function testCannotApproveBelowThreshold() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        vm.startPrank(VOTER1);
        oracle.vote(voteData);
        vm.stopPrank();

        oracle.approve(1);
        assertEq(oracle.nextApproveNonce(), 0);
    }

    // test: get msg hashes
    function testGetMsgHashes() public {
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        vm.startPrank(VOTER1);
        oracle.vote(voteData);
        vm.stopPrank();

        bytes32 msgHash = keccak256(abi.encode(
            voteData[0].sender,
            voteData[0].target,
            voteData[0].value,
            voteData[0].nonce,
            voteData[0].message
        ));

        bytes32[] memory hashes = oracle.getMsgHashes(0);
        assertEq(hashes.length, 1);
        assertEq(hashes[0], msgHash);
    }

    // test: multiple msg hashes
    function testMultipleMsgHashes() public {
        IMsgOracle.VoteData[] memory voteData1 = new IMsgOracle.VoteData[](1);
        voteData1[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message1"
        });

        IMsgOracle.VoteData[] memory voteData2 = new IMsgOracle.VoteData[](1);
        voteData2[0] = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 1,
            message: "message2"
        });

        vm.startPrank(VOTER1);
        oracle.vote(voteData1);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voteData2);
        vm.stopPrank();

        bytes32[] memory hashes = oracle.getMsgHashes(1);
        assertEq(hashes.length, 1);
    }

    // test: multiple votes for multiple msg hashes, nonce 0 satisfy threshold, nonce 1 not satisfy threshold, can approve nonce 0
    function testMultipleVotesSuccess() public {
        IMsgOracle.VoteData memory voteData1 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message1"
        });
        IMsgOracle.VoteData memory voteData2 = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 1,
            message: "message2"
        });
        IMsgOracle.VoteData memory voteData3 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 1,
            message: "message3"
        });

        IMsgOracle.VoteData[] memory voter1Data = new IMsgOracle.VoteData[](2);
        voter1Data[0] = voteData1;
        voter1Data[1] = voteData2;
        IMsgOracle.VoteData[] memory voter2Data = new IMsgOracle.VoteData[](2);
        voter2Data[0] = voteData1;
        voter2Data[1] = voteData3;

        vm.startPrank(VOTER1);
        oracle.vote(voter1Data);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voter2Data);
        vm.stopPrank();

        // approve, only nonce 0 should be approved
        vm.mockCall(
            address(mockMailbox),
            abi.encodeWithSelector(
                MockL2Mailbox.approveMsg.selector,
                voteData2.sender,
                voteData2.target,
                voteData2.value,
                voteData2.nonce,
                voteData2.message
            ),
            ""
        );

        oracle.approve(2);
        assertEq(oracle.nextApproveNonce(), 1);
    }

    // test: multiple votes for multiple msg hashes, nonce 0 satisfy threshold, nonce 1 satisfy threshold, can approve nonce 0 and nonce1
    function testMultipleVotesSuccess_1() public {
        IMsgOracle.VoteData memory voteData1 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message1"
        });
        IMsgOracle.VoteData memory voteData2 = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 1,
            message: "message2"
        });

        IMsgOracle.VoteData[] memory voter1Data = new IMsgOracle.VoteData[](2);
        voter1Data[0] = voteData1;
        voter1Data[1] = voteData2;
        IMsgOracle.VoteData[] memory voter2Data = new IMsgOracle.VoteData[](2);
        voter2Data[0] = voteData1;
        voter2Data[1] = voteData2;

        vm.startPrank(VOTER1);
        oracle.vote(voter1Data);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voter2Data);
        vm.stopPrank();

        // approve, nonce 0 and nonce 1 both should be approved
        vm.mockCall(
            address(mockMailbox),
            abi.encodeWithSelector(
                MockL2Mailbox.approveMsg.selector,
                voteData2.sender,
                voteData2.target,
                voteData2.value,
                voteData2.nonce,
                voteData2.message
            ),
            ""
        );

        oracle.approve(2);
        assertEq(oracle.nextApproveNonce(), 2);
    }

    // test: multiple votes for multiple msg hashes, nonce 0, nonce 1 and nonce2 all satisfy threshold
    function testMultipleVotesSuccess_2() public {
        IMsgOracle.VoteData memory voteData1 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message1"
        });
        IMsgOracle.VoteData memory voteData2 = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 1,
            message: "message2"
        });
        IMsgOracle.VoteData memory voteData3 = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 2,
            message: "message3"
        });

        IMsgOracle.VoteData[] memory voter1Data = new IMsgOracle.VoteData[](3);
        voter1Data[0] = voteData1;
        voter1Data[1] = voteData2;
        voter1Data[2] = voteData3;
        IMsgOracle.VoteData[] memory voter2Data = new IMsgOracle.VoteData[](3);
        voter2Data[0] = voteData1;
        voter2Data[1] = voteData2;
        voter2Data[2] = voteData3;

        vm.startPrank(VOTER1);
        oracle.vote(voter1Data);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voter2Data);
        vm.stopPrank();

        // approve, nonce 0 and nonce 1 both should be approved
        vm.mockCall(
            address(mockMailbox),
            abi.encodeWithSelector(
                MockL2Mailbox.approveMsg.selector,
                voteData2.sender,
                voteData2.target,
                voteData2.value,
                voteData2.nonce,
                voteData2.message
            ),
            ""
        );

        oracle.approve(2);
        assertEq(oracle.nextApproveNonce(), 2);
    }

    // test: multiple votes for multiple msg hashes, nonce 0 not satisfy threshold, nonce 1 satisfy threshold, can not approve
    function testMultipleVotesFailed() public {
        IMsgOracle.VoteData memory voteData1 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message1"
        });
        IMsgOracle.VoteData memory voteData2 = IMsgOracle.VoteData({
            sender: address(0x11),
            target: address(0x21),
            value: 2 ether,
            nonce: 1,
            message: "message2"
        });
        IMsgOracle.VoteData memory voteData3 = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "message3"
        });

        IMsgOracle.VoteData[] memory voter1Data = new IMsgOracle.VoteData[](2);
        voter1Data[0] = voteData1;
        voter1Data[1] = voteData2;
        IMsgOracle.VoteData[] memory voter2Data = new IMsgOracle.VoteData[](2);
        voter2Data[0] = voteData3;
        voter2Data[1] = voteData2;

        vm.startPrank(VOTER1);
        oracle.vote(voter1Data);
        vm.stopPrank();
        vm.startPrank(VOTER2);
        oracle.vote(voter2Data);
        vm.stopPrank();

        // check nonce and msg hashes
        bytes32[] memory hashes = oracle.getMsgHashes(0);
        assertEq(hashes.length, 2);

        // approve, non should be approved
        vm.mockCall(
            address(mockMailbox),
            abi.encodeWithSelector(
                MockL2Mailbox.approveMsg.selector,
                voteData2.sender,
                voteData2.target,
                voteData2.value,
                voteData2.nonce,
                voteData2.message
            ),
            ""
        );

        oracle.approve(2);
        assertEq(oracle.nextApproveNonce(), 0);
    }

    // test: invalid maxApproveCount
    function testInvalidMaxApproveCount() public {
        vm.expectRevert("Invalid maxApproveCount");
        oracle.approve(0);
    }

    // test: owner functions
    function testAddVoter() public {
        oracle.removeVoter(VOTER3);
        address newVoter = address(0x5);
        oracle.addVoter(newVoter);
        assertTrue(oracle.isVoter(newVoter));
        newVoter = address(0x6);
        vm.expectRevert("Invalid threshold");
        oracle.addVoter(newVoter);
    }

    function testRemoveVoter() public {
        oracle.removeVoter(VOTER3);
        assertFalse(oracle.isVoter(VOTER3));
    }

    function testSetThreshold() public {
        uint256 newThreshold = 3;
        oracle.setThreshold(newThreshold);
        assertEq(oracle.threshold(), newThreshold);
    }

    function testSetSmallThreshold() public {
        uint256 newThreshold = 1;
        vm.expectRevert("Invalid threshold");
        oracle.setThreshold(newThreshold);
    }

    function testNonOwnerCannotSetThreshold() public {
        uint256 newThreshold = 1;
        vm.expectRevert();
        vm.prank(NON_VOTER);
        oracle.setThreshold(newThreshold);
    }

    function testSetNextApproveNonce() public {
        uint256 newNextApproveNonce = 100;
        oracle.setNextApproveNonce(newNextApproveNonce);
        assertEq(oracle.nextApproveNonce(), newNextApproveNonce);
    }

    function testNonOwnerCannotSetNextApproveNonce() public {
        uint256 newNextApproveNonce = 100;
        vm.expectRevert();
        vm.prank(NON_VOTER);
        oracle.setNextApproveNonce(newNextApproveNonce);
    }

    function testNonOwnerCannotAddVoter() public {
        address newVoter = address(0x5);
        vm.expectRevert();
        vm.prank(NON_VOTER);
        oracle.addVoter(newVoter);
    }

    function testCannotRemoveLastVoter() public {
        // Remove all but one voter
        oracle.removeVoter(VOTER3);
        vm.expectRevert("Threshold too high");
        oracle.removeVoter(VOTER2);
    }

    function testCannotSetThresholdTooHigh() public {
        uint256 tooHighThreshold = 4; // More than current voters (3)
        vm.expectRevert("Invalid threshold");
        oracle.setThreshold(tooHighThreshold);
    }

    // test: pausable functionality
    function testPauseAndUnpause() public {
        // Test pause
        oracle.pause();
        assertTrue(oracle.paused());

        // Test vote when paused
        IMsgOracle.VoteData[] memory voteData = new IMsgOracle.VoteData[](1);
        voteData[0] = IMsgOracle.VoteData({
            sender: address(0x10),
            target: address(0x20),
            value: 1 ether,
            nonce: 0,
            message: "test message"
        });

        vm.expectRevert("Pausable: paused");
        vm.prank(VOTER1);
        oracle.vote(voteData);

        // Test approve when paused
        oracle.approve(1);

        // Test unpause
        oracle.unpause();
        assertFalse(oracle.paused());

        // Now voting should work
        vm.prank(VOTER1);
        oracle.vote(voteData); // Should not revert
    }

    function testNonOwnerCannotPause() public {
        vm.expectRevert();
        vm.prank(NON_VOTER);
        oracle.pause();
    }

    function testNonOwnerCannotUnpause() public {
        oracle.pause();
        vm.expectRevert();
        vm.prank(NON_VOTER);
        oracle.unpause();
    }
}

