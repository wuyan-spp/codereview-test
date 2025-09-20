// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import "dcap-attestation/types/Constants.sol";
import {BytesUtils} from "dcap-attestation/utils/BytesUtils.sol";
// import "forge-std/console.sol";

contract MeasurementDao is Ownable {
    using BytesUtils for bytes;

    mapping(bytes32 => bytes32) private mr;
    bytes32[] private mrEnclaveList;
    mapping(bytes32 => uint256) private mrEnclaveIndex;

    mapping(bytes => bool) private rtmr;
    bytes[] private rtmrList;
    mapping(bytes => uint256) private rtmrIndex;

    mapping(bytes => bool) private mrtdMap;
    bytes[] private mrtdList;
    mapping(bytes => uint256) private mrtdIndex; 

    uint16 private constant MR_ENCLAVE_OFFSET = 112;
    uint16 private constant MR_SIGNER_OFFSET = 176;

    error AlreadyExists();
    error NotExists();

    constructor() {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice
     * @param _mrEnclave measurement of enclave
     * @param _mrSigner measurement of signer
     */
    function add_mr_enclave(bytes32 _mrEnclave, bytes32 _mrSigner) external onlyOwner {
        if (mr[_mrEnclave] != bytes32(0)) revert AlreadyExists();
        mr[_mrEnclave] = _mrSigner;
        mrEnclaveIndex[_mrEnclave] = mrEnclaveList.length;
        mrEnclaveList.push(_mrEnclave);
    }

    /**
     * @notice
     * @param _mrEnclave measurement of enclave
     */
    function delete_mr_enclave(bytes32 _mrEnclave) external onlyOwner {
        if (mr[_mrEnclave] == bytes32(0)) revert NotExists();
        delete mr[_mrEnclave];

        uint256 index = mrEnclaveIndex[_mrEnclave];
        require(index < mrEnclaveList.length, "Invalid index");
        bytes32 lastElement = mrEnclaveList[mrEnclaveList.length - 1];
        mrEnclaveList[index] = lastElement;
        mrEnclaveIndex[lastElement] = index;
        
        mrEnclaveList.pop();
        delete mrEnclaveIndex[_mrEnclave];
    }

    function get_mr_enclave() external view returns (bytes32[] memory) {
        return mrEnclaveList;
    }

    function clearup_mr_enclave() external onlyOwner {
        for (uint256 i = 0; i < mrEnclaveList.length; ++i) {
            delete mr[mrEnclaveList[i]];
            delete mrEnclaveIndex[mrEnclaveList[i]];
        }
        delete mrEnclaveList;
    }

    /**
     * @notice
     * @param rtmr3
     */
    function add_rtMr(bytes calldata rtmr3) external onlyOwner {
        if (rtmr[rtmr3]) revert AlreadyExists();
        rtmr[rtmr3] = true;
        rtmrIndex[rtmr3] = rtmrList.length;
        rtmrList.push(rtmr3);
    }

    /**
     * @notice
     * @param rtmr3
     */
    function delete_rtMr(bytes calldata rtmr3) external onlyOwner {
        if (!rtmr[rtmr3]) revert NotExists();
        delete rtmr[rtmr3];
        uint256 index = rtmrIndex[rtmr3];
        require(index < rtmrList.length, "Invalid index");
        bytes memory lastElement = rtmrList[rtmrList.length - 1];
        rtmrList[index] = lastElement;
        rtmrIndex[lastElement] = index;   
        rtmrList.pop();
        delete rtmrIndex[rtmr3];
    }

    function get_rtMr() external view returns (bytes[] memory) {
        return rtmrList;
    }

    function clearup_rtMr() external onlyOwner {
        for (uint256 i = 0; i < rtmrList.length; ++i) {
            delete rtmr[rtmrList[i]];
            delete rtmrIndex[rtmrList[i]];
        }
        delete rtmrList;
    }

    function add_mrtd(bytes calldata mrtd) external onlyOwner {
        if (mrtdMap[mrtd]) revert AlreadyExists();
        mrtdMap[mrtd] = true;
        mrtdIndex[mrtd] = mrtdList.length;
        mrtdList.push(mrtd);
    }

    function delete_mrtd(bytes calldata mrtd) external onlyOwner {
        if (!mrtdMap[mrtd]) revert NotExists();
        delete mrtdMap[mrtd];

        uint256 index = mrtdIndex[mrtd];
        require(index < mrtdList.length, "Invalid index");
        bytes memory lastElement = mrtdList[mrtdList.length - 1];
        mrtdList[index] = lastElement;
        mrtdIndex[lastElement] = index;
        mrtdList.pop();
        delete mrtdIndex[mrtd];
    }

    function get_mrtd() external view returns (bytes[] memory) {
        return mrtdList;
    }

    function clearup_mrtd() external onlyOwner {
        for (uint256 i = 0; i < mrtdList.length; ++i) {
            delete mrtdMap[mrtdList[i]];
            delete mrtdIndex[mrtdList[i]];
        }
        delete mrtdList;
    }

    function verifyMeasurementSGX(bytes calldata quote, uint16 quoteVersion) external view returns (bool) {
        uint256 mrEnclaveOffset;
        uint256 mrSignerOffset;
        if (quoteVersion == 3) {
            mrEnclaveOffset = MR_ENCLAVE_OFFSET;
            mrSignerOffset = MR_SIGNER_OFFSET;
        } else if (quoteVersion == 4) {
            mrEnclaveOffset = HEADER_LENGTH + 64;
            mrSignerOffset = HEADER_LENGTH + 128;
        } else if (quoteVersion == 5) {
            return false; // quotev5 not support sgx
        } else {
            return false;
        }

        bytes32 mrEnclave = bytes32(quote.substring(mrEnclaveOffset, 32));
        bytes32 mrSigner = bytes32(quote.substring(mrSignerOffset, 32));
        return mrSigner != bytes32(0) && mr[mrEnclave] == mrSigner; //mrSigner not zero
    }

    function verifyMeasurementTDX(bytes calldata quote, uint16 quoteVersion) external view returns (bool) {
        uint256 rtmr3Offset;

        if (quoteVersion == 3) {
            return false; // quotev3 not support tdx
        } else if (quoteVersion == 4) {
            rtmr3Offset = HEADER_LENGTH + 472;
        } else if (quoteVersion == 5) {
            rtmr3Offset = HEADER_LENGTH + 6 + 472;
        } else {
            return false;
        }

        bytes memory rtmr3 = quote.substring(rtmr3Offset, 48);
        return rtmr[rtmr3];
    }

    function verifyMRTD(bytes calldata quote, uint16 quoteVersion) external view returns (bool) {
        uint256 mrtdOffset;

        if (quoteVersion == 3) {
            return false; // quotev3 not support tdx
        } else if (quoteVersion == 4) {
            mrtdOffset = HEADER_LENGTH + 136;
        } else if (quoteVersion == 5) {
            mrtdOffset = HEADER_LENGTH + 6 + 136;
        } else {
            return false;
        }

        bytes memory mrtd = quote.substring(mrtdOffset, 48);
        return mrtdMap[mrtd];
    }
}
