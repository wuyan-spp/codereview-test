// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "solady/auth/Ownable.sol";
import "dcap-attestation/types/Constants.sol";
import {BytesUtils} from "dcap-attestation/utils/BytesUtils.sol";

/**
 * @title MeasurementDao
 * @notice Contract for managing TEE measurements including MR_ENCLAVE, MR_SIGNER, RTMR, and MRTD
 * @dev This contract stores and manages various measurement values used for TEE attestation verification
 * @dev Uses independent version-based storage for each data type to avoid O(n) gas costs when clearing mappings
 */
contract MeasurementDao is Ownable {
    using BytesUtils for bytes;

    // Independent version numbers for each data type
    uint256 private mrEnclaveVersion = 1;
    uint256 private rtMrVersion = 1;
    uint256 private mrtdVersion = 1;

    // MR_ENCLAVE storage with versioning
    mapping(uint256 => mapping(bytes32 => bytes32)) private mr;
    mapping(uint256 => bytes32[]) private mrEnclaveList;
    mapping(uint256 => mapping(bytes32 => uint256)) private mrEnclaveIndex;

    // RTMR storage with versioning
    mapping(uint256 => mapping(bytes => bool)) private rtmr;
    mapping(uint256 => bytes[]) private rtmrList;
    mapping(uint256 => mapping(bytes => uint256)) private rtmrIndex;

    // MRTD storage with versioning
    mapping(uint256 => mapping(bytes => bool)) private mrtdMap;
    mapping(uint256 => bytes[]) private mrtdList;
    mapping(uint256 => mapping(bytes => uint256)) private mrtdIndex;

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
        require(_mrEnclave != bytes32(0), ZeroValue());
        require(_mrSigner != bytes32(0), ZeroValue());
        require(mr[mrEnclaveVersion][_mrEnclave] == bytes32(0), AlreadyExists());
        mr[mrEnclaveVersion][_mrEnclave] = _mrSigner;
        mrEnclaveList[mrEnclaveVersion].push(_mrEnclave);
        mrEnclaveIndex[mrEnclaveVersion][_mrEnclave] = mrEnclaveList[mrEnclaveVersion].length;
    }

    /**
     * @notice Delete an MR_ENCLAVE and its corresponding MR_SIGNER
     * @param _mrEnclave The measurement register of the enclave to delete
     */
    function deleteMrEnclave(bytes32 _mrEnclave) external onlyOwner {
        require(mr[mrEnclaveVersion][_mrEnclave] != bytes32(0), NotExists());
        delete mr[mrEnclaveVersion][_mrEnclave];
        
        uint256 index = mrEnclaveIndex[mrEnclaveVersion][_mrEnclave];
        require(index > 0 && index <= mrEnclaveList[mrEnclaveVersion].length, "Invalid index");
        bytes32 lastElement = mrEnclaveList[mrEnclaveVersion][mrEnclaveList[mrEnclaveVersion].length - 1];
        mrEnclaveList[mrEnclaveVersion][index - 1] = lastElement;
        mrEnclaveIndex[mrEnclaveVersion][lastElement] = index;
        
        mrEnclaveList[mrEnclaveVersion].pop();
        delete mrEnclaveIndex[mrEnclaveVersion][_mrEnclave];
    }

    /**
     * @notice Get all registered MR_ENCLAVE values for the current version
     * @return Array of all MR_ENCLAVE values
     */
    function getMrEnclave() external view returns (bytes32[] memory) {
        return mrEnclaveList[mrEnclaveVersion];
    }

    /**
     * @notice Clear all MR_ENCLAVE and MR_SIGNER mappings by incrementing version
     * @dev This avoids O(n) gas cost by using version-based storage
     */
    function clearMrEnclave() external onlyOwner {
        mrEnclaveVersion += 1;
    }

    /**
     * @notice Add a new RTMR (Runtime Measurement Register) value for TDX verification
     * @param rtmr3 The RTMR3 value to add (48 bytes for TDX)
     */
    function addRtmr(bytes calldata rtmr3) external onlyOwner {
        require(rtmr3.length == 48, InvalidLength());
        require(rtmr3.length != 0 && keccak256(rtmr3) != keccak256(bytes("")), ZeroValue());
        require(!rtmr[rtMrVersion][rtmr3], AlreadyExists());
        rtmr[rtMrVersion][rtmr3] = true;
        rtmrList[rtMrVersion].push(rtmr3);
        rtmrIndex[rtMrVersion][rtmr3] = rtmrList[rtMrVersion].length;
    }

    /**
     * @notice Delete an RTMR value from the registry
     * @param rtmr3 The RTMR3 value to delete
     */
    function deleteRtmr(bytes calldata rtmr3) external onlyOwner {
        require(rtmr[rtMrVersion][rtmr3], NotExists());
        delete rtmr[rtMrVersion][rtmr3];
        
        uint256 index = rtmrIndex[rtMrVersion][rtmr3];
        require(index > 0 && index <= rtmrList[rtMrVersion].length, "Invalid index");
        bytes memory lastElement = rtmrList[rtMrVersion][rtmrList[rtMrVersion].length - 1];
        rtmrList[rtMrVersion][index - 1] = lastElement;
        rtmrIndex[rtMrVersion][lastElement] = index;   
        rtmrList[rtMrVersion].pop();
        delete rtmrIndex[rtMrVersion][rtmr3];
    }

    /**
     * @notice Get all registered RTMR values for the current version
     * @return Array of all RTMR values
     */
    function getRtmr() external view returns (bytes[] memory) {
        return rtmrList[rtMrVersion];
    }

    /**
     * @notice Clear all RTMR mappings and lists by incrementing version
     * @dev This avoids O(n) gas cost by using version-based storage
     */
    function clearRtmr() external onlyOwner {
        rtMrVersion += 1;
    }

    /**
     * @notice Add a new MRTD (Measurement Register for TD) value for TDX verification
     * @param mrtd The MRTD value to add (48 bytes for TDX)
     */
    function addMrtd(bytes calldata mrtd) external onlyOwner {
        require(mrtd.length == 48, InvalidLength());
        require(mrtd.length != 0 && keccak256(mrtd) != keccak256(bytes("")), ZeroValue());
        require(!mrtdMap[mrtdVersion][mrtd], AlreadyExists());
        mrtdMap[mrtdVersion][mrtd] = true;
        mrtdList[mrtdVersion].push(mrtd);
        mrtdIndex[mrtdVersion][mrtd] = mrtdList[mrtdVersion].length;
    }

    /**
     * @notice Delete an MRTD value from the registry
     * @param mrtd The MRTD value to delete
     */
    function deleteMrtd(bytes calldata mrtd) external onlyOwner {
        require(mrtdMap[mrtdVersion][mrtd], NotExists());
        delete mrtdMap[mrtdVersion][mrtd];
        
        uint256 index = mrtdIndex[mrtdVersion][mrtd];
        require(index > 0 && index <= mrtdList[mrtdVersion].length, "Invalid index");
        bytes memory lastElement = mrtdList[mrtdVersion][mrtdList[mrtdVersion].length - 1];
        mrtdList[mrtdVersion][index - 1] = lastElement;
        mrtdIndex[mrtdVersion][lastElement] = index;
        mrtdList[mrtdVersion].pop();
        delete mrtdIndex[mrtdVersion][mrtd];
    }

    /**
     * @notice Get all registered MRTD values for the current version
     * @return Array of all MRTD values
     */
    function getMrtd() external view returns (bytes[] memory) {
        return mrtdList[mrtdVersion];
    }

    /**
     * @notice Clear all MRTD mappings and lists by incrementing version
     * @dev This avoids O(n) gas cost by using version-based storage
     */
    function clearMrtd() external onlyOwner {
        mrtdVersion += 1;
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
        return mrSigner != bytes32(0) && mr[mrEnclaveVersion][mrEnclave] == mrSigner; //mrSigner not zero
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
        return rtmr[rtMrVersion][rtmr3];
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
        return mrtdMap[mrtdVersion][mrtd];
    }
}
