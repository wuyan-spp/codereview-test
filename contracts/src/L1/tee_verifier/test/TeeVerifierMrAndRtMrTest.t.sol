// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/PCCSSetupBase.sol";

import {AutomataDcapAttestationFee} from "dcap-attestation/AutomataDcapAttestationFee.sol";
import {V3QuoteVerifier} from "dcap-attestation/verifiers/V3QuoteVerifier.sol";
import {V5QuoteVerifier} from "dcap-attestation/verifiers/V5QuoteVerifier.sol";

import {BytesUtils} from "dcap-attestation/utils/BytesUtils.sol";
import {DCAPAttestationRouter} from "../src/DCAPAttestationRouter.sol";
import {TEECacheVerifier} from "../src/TEECacheVerifier.sol";
import {DaimoP256Verifier} from "../script/utils/DaimoP256Verifier.sol";
import "./utils/Constants.sol";
import {MeasurementRegistry} from "../src/MeasurementRegistry.sol";

library BytesArrayUtils {
    function contains(bytes[] memory self, bytes memory target) external pure returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (keccak256(abi.encodePacked(self[i])) == keccak256(abi.encodePacked(target))) {
                return true;
            }
        }
        return false;
    }

    function contains(bytes32[] memory self, bytes32 target) external pure returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i] == target) {
                return true;
            }
        }
        return false;
    }
}

contract TEEVerifyTest is PCCSSetupBase {
    using BytesUtils for bytes;
    using BytesArrayUtils for bytes[];
    using BytesArrayUtils for bytes32[];

    AutomataDcapAttestationFee attestation;
    PCCSRouter pccsRouter;
    DCAPAttestationRouter router;
    MeasurementRegistry mrDao;
    DaimoP256Verifier p256verifier;
    TEECacheVerifier cacheVerifier;

    address user = address(69);

    function setUp() public override {
        super.setUp();

        vm.deal(user, 1 ether);
        vm.txGasPrice(GAS_PRICE_WEI);

        vm.startPrank(admin);

        // PCCS Setup
        pccsRouter = setupPccsRouter(admin);
        pcsDaoUpserts();

        // DCAP Contract Deployment
        attestation = new AutomataDcapAttestationFee(admin);

        mrDao = new MeasurementRegistry();

        //TEECacheVerifier Deployment
        p256verifier = new DaimoP256Verifier();
        cacheVerifier = new TEECacheVerifier(address(p256verifier));

        router = new DCAPAttestationRouter(address(attestation), address(mrDao), address(cacheVerifier));
        router.setConfig(address(attestation), address(mrDao), false, address(cacheVerifier), true);

        vm.stopPrank();
    }

    function testMRandRTMROFF() public {
        vm.startPrank(admin);
        router.setConfig(address(attestation), address(mrDao), false, address(cacheVerifier), true);
        vm.stopPrank();
        assertEq(router.toVerifyMr(), false);
    }

    function testMRandRTMRON() public {
        vm.startPrank(admin);
        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        vm.stopPrank();
        assertEq(router.toVerifyMr(), true);
    }

    function testMRTDOFF() public {
        vm.startPrank(admin);
        router.disableVerifyMrtd();
        vm.stopPrank();
        assertEq(router.toVerifyMrtd(), false);
    }

    function testMRTDON() public {
        vm.startPrank(admin);
        router.enableVerifyMrtd();
        vm.stopPrank();
        assertEq(router.toVerifyMrtd(), true);
    }

    function testAddMulMR() public {
        vm.startPrank(admin);
        mrDao.addMrEnclave(mrEnclave_1, mrSigner_1);
        mrDao.addMrEnclave(mrEnclave_2, mrSigner_2);
        bytes32[] memory mrEnclaveList = mrDao.getMrEnclave();
        vm.stopPrank();
        assertEq(mrEnclaveList.contains(mrEnclave_1), true);
        assertEq(mrEnclaveList.contains(mrEnclave_2), true);
    }

    function testDeletMR() public {
        vm.startPrank(admin);
        mrDao.addMrEnclave(mrEnclave_1, mrSigner_1);
        mrDao.deleteMrEnclave(mrEnclave_1);
        bytes32[] memory mrEnclaveList = mrDao.getMrEnclave();
        vm.stopPrank();
        assertEq(mrEnclaveList.contains(mrEnclave_1), false);
    }

    function testClearupMR() public {
        vm.startPrank(admin);
        mrDao.addMrEnclave(mrEnclave_1, mrSigner_1);
        mrDao.addMrEnclave(mrEnclave_2, mrSigner_2);
        mrDao.clearMrEnclave();
        bytes32[] memory mrEnclaveList = mrDao.getMrEnclave();
        vm.stopPrank();
        assertEq(mrEnclaveList.length, 0);
    }

    function testAddMulRTMR() public {
        vm.startPrank(admin);
        mrDao.addRtmr(rtmr3_1);
        mrDao.addRtmr(rtmr3_2);
        bytes[] memory rtMrList = mrDao.getRtmr();
        vm.stopPrank();
        assertEq(rtMrList.contains(rtmr3_1), true);
        assertEq(rtMrList.contains(rtmr3_2), true);
    }

    function testDeletRTMR() public {
        vm.startPrank(admin);
        mrDao.addRtmr(rtmr3_1);
        mrDao.deleteRtmr(rtmr3_1);
        bytes[] memory rtMrList = mrDao.getRtmr();
        vm.stopPrank();
        assertEq(rtMrList.contains(rtmr3_1), false);
    }

    function testClearupRTMR() public {
        vm.startPrank(admin);
        mrDao.addRtmr(rtmr3_1);
        mrDao.addRtmr(rtmr3_2);
        mrDao.clearRtmr();
        bytes[] memory rtMrList = mrDao.getRtmr();
        vm.stopPrank();
        assertEq(rtMrList.length, 0);
    }

    function testAddMulMrtd() public {
        vm.startPrank(admin);
        mrDao.addMrtd(mrtd_1);
        mrDao.addMrtd(mrtd_2);
        bytes[] memory mrtdList = mrDao.getMrtd();
        vm.stopPrank();
        assertEq(mrtdList.contains(mrtd_1), true);
        assertEq(mrtdList.contains(mrtd_2), true);
    }

    function testDeletMrtd() public {
        vm.startPrank(admin);
        mrDao.addMrtd(mrtd_1);
        mrDao.deleteMrtd(mrtd_1);
        bytes[] memory mrtdList = mrDao.getMrtd();
        vm.stopPrank();
        assertEq(mrtdList.contains(mrtd_1), false);
    }

    function testClearupMrtd() public {
        vm.startPrank(admin);
        mrDao.addMrtd(mrtd_1);
        mrDao.addMrtd(mrtd_2);
        mrDao.clearMrtd();
        bytes[] memory mrtdList = mrDao.getMrtd();
        vm.stopPrank();
        assertEq(mrtdList.length, 0);
    }

    function testExceptionNoMrtoVerifyV3() public {
        vm.startPrank(admin);
        mrDao.clearMrEnclave();
        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);

        cacheVerifier.setAuthorized(address(router), true);

        
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MrValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote3_1);
        vm.stopPrank();
    }

    function testExceptionUsingWrongMrtoVerifyV3() public {
        vm.startPrank(admin);
        mrDao.clearMrEnclave();
        mrDao.addMrEnclave(mrEnclave_1, mrSigner_1);
        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        cacheVerifier.setAuthorized(address(router), true);
        
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MrValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote3_2);
        vm.stopPrank();
    }

    function testExceptionDeleteWrongMr() public {
        vm.startPrank(admin);
        mrDao.clearMrEnclave();
        mrDao.addMrEnclave(mrEnclave_1, mrSigner_1);
        vm.expectRevert(abi.encodeWithSelector(MeasurementRegistry.NotExists.selector));
        mrDao.deleteMrEnclave(mrEnclave_2);
        vm.stopPrank();
    }

    function testExceptionNoRTMRtoVerifyV5() public {
        vm.startPrank(admin);
        mrDao.clearRtmr();
        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        cacheVerifier.setAuthorized(address(router), true);
        
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MrValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote5_1);
        vm.stopPrank();
    }

    function testExceptionUsingWrongRTMRtoVerifyV5() public {
        vm.startPrank(admin);
        mrDao.clearRtmr();
        mrDao.addRtmr(rtmr3_1);
        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        cacheVerifier.setAuthorized(address(router), true);
        
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MrValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote5_2);
        vm.stopPrank();
    }

    function testExceptionDeleteWrongRTMR() public {
        vm.startPrank(admin);
        mrDao.clearRtmr();
        mrDao.addRtmr(rtmr3_1);
        vm.expectRevert(abi.encodeWithSelector(MeasurementRegistry.NotExists.selector));
        mrDao.deleteRtmr(rtmr3_2);
        vm.stopPrank();
    }

    function testExceptionNoMRTDtoVerifyV5() public {
        vm.startPrank(admin);
        mrDao.clearRtmr();
        mrDao.clearMrtd();
        mrDao.addRtmr(rtmr3_1);

        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        router.enableVerifyMrtd();
        cacheVerifier.setAuthorized(address(router), true);
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MRTDValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote5_1);
        vm.stopPrank();
    }

    function testExceptionUsingWrongMRTDtoVerifyV5() public {
        vm.startPrank(admin);
        mrDao.clearRtmr();
        mrDao.clearMrtd();
        mrDao.addRtmr(rtmr3_1);
        mrDao.addMrtd(mrtd_2);

        router.setConfig(address(attestation), address(mrDao), true, address(cacheVerifier), true);
        router.enableVerifyMrtd();
        cacheVerifier.setAuthorized(address(router), true);
        vm.expectRevert(abi.encodeWithSelector(DCAPAttestationRouter.MRTDValidationFailed.selector));
        (uint32 success,) = router.verifyProof(sampleQuote5_1);
        vm.stopPrank();
    }
}
