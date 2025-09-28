// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "solady/auth/Ownable.sol";
import "dcap-attestation/types/Constants.sol";
import {BytesUtils} from "dcap-attestation/utils/BytesUtils.sol";

/**
 * @title MeasurementDao
 * @notice Contract for managing TEE measurements including MR_ENCLAVE, MR_SIGNER, RTMR, and MRTD
 * @dev This contract stores and manages various measurement values used for TEE attestation verification
 */
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
    error InvalidLength();
    error ZeroValue();

    constructor() {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Add a new MR_ENCLAVE and MR_SIGNER pair for SGX verification
     * @param _mrEnclave The measurement register of the enclave (32 bytes)
     * @param _mrSigner The measurement register of the signer (32 bytes)
     */
    function addMrEnclave(bytes32 _mrEnclave, bytes32 _mrSigner) external onlyOwner {
        if (_mrSigner == bytes32(0)) revert ZeroValue();
        if (mr[_mrEnclave] != bytes32(0)) revert AlreadyExists();
        mr[_mrEnclave] = _mrSigner;
        mrEnclaveList.push(_mrEnclave);
        mrEnclaveIndex[_mrEnclave] = mrEnclaveList.length;
    }

    /**
     * @notice Delete an MR_ENCLAVE and its corresponding MR_SIGNER
     * @param _mrEnclave The measurement register of the enclave to delete
     */
    function deleteMrEnclave(bytes32 _mrEnclave) external onlyOwner {
        if (mr[_mrEnclave] == bytes32(0)) revert NotExists();
        delete mr[_mrEnclave];

        uint256 index = mrEnclaveIndex[_mrEnclave];
        require(index > 0 && index <= mrEnclaveList.length, "Invalid index");
        bytes32 lastElement = mrEnclaveList[mrEnclaveList.length - 1];
        mrEnclaveList[index - 1] = lastElement;
        mrEnclaveIndex[lastElement] = index;

        mrEnclaveList.pop();
        delete mrEnclaveIndex[_mrEnclave];
    }

    /**
     * @notice Get all registered MR_ENCLAVE values
     * @return Array of all MR_ENCLAVE values
     */
    function getMrEnclave() external view returns (bytes32[] memory) {
        return mrEnclaveList;
    }

    /**
     * @notice Clear all MR_ENCLAVE and MR_SIGNER mappings
     */
    function clearMrEnclave() external onlyOwner {
        for (uint256 i = 0; i < mrEnclaveList.length; ++i) {
            delete mr[mrEnclaveList[i]];
            delete mrEnclaveIndex[mrEnclaveList[i]];
        }
        delete mrEnclaveList;
    }

    /**
     * @notice Add a new RTMR (Runtime Measurement Register) value for TDX verification
     * @param rtmr3 The RTMR3 value to add (48 bytes for TDX)
     */
    function addRtmr(bytes calldata rtmr3) external onlyOwner {
        if (rtmr3.length != 48) revert InvalidLength();
        if (rtmr[rtmr3]) revert AlreadyExists();
        rtmr[rtmr3] = true;
        rtmrList.push(rtmr3);
        rtmrIndex[rtmr3] = rtmrList.length;
    }

    /**
     * @notice Delete an RTMR value from the registry
     * @param rtmr3 The RTMR3 value to delete
     */
    function deleteRtmr(bytes calldata rtmr3) external onlyOwner {
        if (!rtmr[rtmr3]) revert NotExists();
        delete rtmr[rtmr3];
        uint256 index = rtmrIndex[rtmr3];
        require(index > 0 && index <= rtmrList.length, "Invalid index");
        bytes memory lastElement = rtmrList[rtmrList.length - 1];
        rtmrList[index - 1] = lastElement;
        rtmrIndex[lastElement] = index;
        rtmrList.pop();
        delete rtmrIndex[rtmr3];
    }

    /**
     * @notice Get all registered RTMR values
     * @return Array of all RTMR values
     */
    function getRtmr() external view returns (bytes[] memory) {
        return rtmrList;
    }

    /**
     * @notice Clear all RTMR mappings and lists
     */
    function clearRtmr() external onlyOwner {
        for (uint256 i = 0; i < rtmrList.length; ++i) {
            delete rtmr[rtmrList[i]];
            delete rtmrIndex[rtmrList[i]];
        }
        delete rtmrList;
    }

    /**
     * @notice Add a new MRTD (Measurement Register for TD) value for TDX verification
     * @param mrtd The MRTD value to add (48 bytes for TDX)
     */
    function addMrtd(bytes calldata mrtd) external onlyOwner {
        if (mrtd.length != 48) revert InvalidLength();
        if (mrtdMap[mrtd]) revert AlreadyExists();
        mrtdMap[mrtd] = true;
        mrtdList.push(mrtd);
        mrtdIndex[mrtd] = mrtdList.length;
    }

    /**
     * @notice Delete an MRTD value from the registry
     * @param mrtd The MRTD value to delete
     */
    function deleteMrtd(bytes calldata mrtd) external onlyOwner {
        if (!mrtdMap[mrtd]) revert NotExists();
        delete mrtdMap[mrtd];

        uint256 index = mrtdIndex[mrtd];
        require(index > 0 && index <= mrtdList.length, "Invalid index");
        bytes memory lastElement = mrtdList[mrtdList.length - 1];
        mrtdList[index - 1] = lastElement;
        mrtdIndex[lastElement] = index;
        mrtdList.pop();
        delete mrtdIndex[mrtd];
    }

    /**
     * @notice Get all registered MRTD values
     * @return Array of all MRTD values
     */
    function getMrtd() external view returns (bytes[] memory) {
        return mrtdList;
    }

    /**
     * @notice Clear all MRTD mappings and lists
     */
    function clearMrtd() external onlyOwner {
        for (uint256 i = 0; i < mrtdList.length; ++i) {
            delete mrtdMap[mrtdList[i]];
            delete mrtdIndex[mrtdList[i]];
        }
        delete mrtdList;
    }

    /**
     * @notice Verify SGX measurement against registered MR_ENCLAVE and MR_SIGNER pairs
     * @param quote The SGX quote data
     * @param quoteVersion The version of the quote format (3, 4, or 5)
     * @return True if the measurement is valid, false otherwise
     */
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

        // Check if the quote is long enough to extract the required data
        if (quote.length <= mrEnclaveOffset + 32 || quote.length <= mrSignerOffset + 32) {
            return false;
        }
        bytes32 mrEnclave = bytes32(quote.substring(mrEnclaveOffset, 32));
        bytes32 mrSigner = bytes32(quote.substring(mrSignerOffset, 32));
        return mrSigner != bytes32(0) && mr[mrEnclave] == mrSigner; //mrSigner not zero
    }

    /**
     * @notice Verify TDX measurement against registered RTMR values
     * @param quote The TDX quote data
     * @param quoteVersion The version of the quote format (3, 4, or 5)
     * @return True if the measurement is valid, false otherwise
     */
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

        // Check if the quote is long enough to extract the required data
        if (quote.length <= rtmr3Offset + 48) {
            return false;
        }
        bytes memory rtmr3 = quote.substring(rtmr3Offset, 48);
        return rtmr[rtmr3];
    }

    /**
     * @notice Verify TDX MRTD (Measurement Register for TD) against registered values
     * @param quote The TDX quote data
     * @param quoteVersion The version of the quote format (3, 4, or 5)
     * @return True if the MRTD is valid, false otherwise
     */
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

        // Check if the quote is long enough to extract the required data
        if (quote.length <= mrtdOffset + 48) {
            return false;
        }
        bytes memory mrtd = quote.substring(mrtdOffset, 48);
        return mrtdMap[mrtd];
    }
}
