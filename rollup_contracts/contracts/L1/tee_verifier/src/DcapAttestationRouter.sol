// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable} from "solady/auth/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {MeasurementDao} from "./MeasurementDao.sol";
import {AutomataDcapAttestationFee} from "dcap-attestation/AutomataDcapAttestationFee.sol";
import {BELE} from "dcap-attestation/utils/BELE.sol";
import {BytesUtils} from "dcap-attestation/utils/BytesUtils.sol";
import {TEECacheVerifier} from "./TEECacheVerifier.sol";
import "dcap-attestation/types/Constants.sol";

/**
 * @title DcapAttestationRouter
 * @notice Contract for verifying TEE attestation quotes from rollup using Intel DCAP attestation
 * @dev This contract acts as a router to verify TEE quotes and optionally verify measurements
 */
contract DcapAttestationRouter is Ownable {
    using BytesUtils for bytes;

    uint16 private constant USER_DATA_V3_OFFSET = 333;
    uint16 private constant USER_DATA_V4_OFFSET = 533;
    uint16 private constant USER_DATA_V5_OFFSET = 539;

    /// @notice Address of the DCAP attestation contract
    address public dcapAttestation;

    /// @notice Address of the measurement DAO contract for verifying measurements
    address public measurementDao;
   
    /// @notice Flag indicating whether to verify measurement registers
    bool public toVerifyMr;
    
    /// @notice Address of the TEE cache verifier contract
    address public cacheVerifierAddr;
   
    /// @notice Flag indicating whether to use cache-based verification
    bool public cacheOption;
    
    /// @notice Mapping of authorized callers
    mapping(address => bool) private _authorized;
    
    /// @notice Flag indicating whether caller restriction is enabled
    bool private _isCallerRestricted = true;
    
    /// @notice Flag indicating whether to verify MRTD (TDX only)
    bool public toVerifyMrtd = false;

    error Forbidden();
    error InvalidAddress();
    error MrValidationFailed();
    error MRTDValidationFailed();

    /// @notice Event emitted when authorization status is changed
    event AuthorizationSet(address indexed caller, bool authorized);
    
    /// @notice Event emitted when caller restriction is enabled
    event CallerRestrictionEnabled();
    
    /// @notice Event emitted when caller restriction is disabled
    event CallerRestrictionDisabled();
    
    /// @notice Event emitted when configuration is updated
    event ConfigUpdated(
        address indexed dcapAttestation,
        address indexed measurementDao,
        bool toVerifyMr,
        address indexed cacheVerifierAddr,
        bool cacheOption
    );
    
    /// @notice Event emitted when MRTD verification is enabled
    event VerifyMRTDEnabled();
    
    /// @notice Event emitted when MRTD verification is disabled
    event VerifyMRTDDisabled();

    modifier onlyAuthorized() {
        require(!_isCallerRestricted || _authorized[msg.sender], Forbidden());
        _;
    }

    constructor(address _dcapAttestation, address _measurementDao, address _cacheVerifierAddr) {
        _initializeOwner(msg.sender);
        _setConfig(_dcapAttestation, _measurementDao, true, _cacheVerifierAddr, true);
    }

    /**
     * @notice Set the configuration for the attestation router
     * @param _dcapAttestation Address of the DCAP attestation contract
     * @param _measurementDao Address of the measurement DAO contract
     * @param _toVerifyMr Flag indicating whether to verify measurement registers
     * @param _cacheVerifierAddr Address of the TEE cache verifier contract
     * @param _cacheOption Flag indicating whether to use cache-based verification
     */
    function setConfig(
        address _dcapAttestation,
        address _measurementDao,
        bool _toVerifyMr,
        address _cacheVerifierAddr,
        bool _cacheOption
    ) external onlyOwner {
        _setConfig(_dcapAttestation, _measurementDao, _toVerifyMr, _cacheVerifierAddr, _cacheOption);
    }

    /**
     * @notice Set authorization status for a caller
     * @param caller Address to set authorization for
     * @param authorized Whether the caller is authorized
     */
    function setAuthorized(address caller, bool authorized) external onlyOwner {
        _authorized[caller] = authorized;
        emit AuthorizationSet(caller, authorized);
    }

   /**
     * @notice Enable caller restriction (only authorized callers can call functions)
     */
    function enableCallerRestriction() external onlyOwner {
        _isCallerRestricted = true;
        emit CallerRestrictionEnabled();
    }

	
    /**
     * @notice Disable caller restriction (anyone can call functions)
     */
    function disableCallerRestriction() external onlyOwner {
        _isCallerRestricted = false;
    }

	
    /**
     * @notice Verify proof from rollup
     * @param aggrProof The aggregated proof containing the TEE quote
     * @return _error_code Error code (0 for success, 1 for failure)
     * @return commitment The extracted commitment from the quote
     */
    function verifyProof(bytes calldata aggrProof)
        external
        onlyAuthorized
        returns (uint32 _error_code, bytes32 commitment)
    {
        (_error_code, commitment) = _verifyProof(aggrProof);
    }

    /**
     * @notice Internal function to set the configuration for the attestation router
     * @param _dcapAttestation Address of the DCAP attestation contract
     * @param _measurementDao Address of the measurement DAO contract
     * @param _toVerifyMr Flag indicating whether to verify measurement registers
     * @param _cacheVerifierAddr Address of the TEE cache verifier contract
     * @param _cacheOption Flag indicating whether to use cache-based verification
     */
    function _setConfig(
        address _dcapAttestation,
        address _measurementDao,
        bool _toVerifyMr,
        address _cacheVerifierAddr,
        bool _cacheOption
    ) private {
        require(_dcapAttestation != address(0), InvalidAddress());
        require(_measurementDao != address(0), InvalidAddress());
        require(_cacheVerifierAddr != address(0), InvalidAddress());
        dcapAttestation = _dcapAttestation;
        measurementDao = _measurementDao;
        toVerifyMr = _toVerifyMr;
        cacheVerifierAddr = _cacheVerifierAddr;
        CacheOption = _CacheOption;
        emit ConfigUpdated(_dcapAttestation, _measurementDao, _toVerifyMr, _cacheVerifierAddr, _CacheOption);
    }

    /**
     * @notice Enable MRTD verification for TDX quotes
     */
    function enableVerifyMrtd() external onlyOwner {
        toVerifyMrtd = true;
        emit VerifyMRTDEnabled();
    }

    /**
     * @notice Disable MRTD verification for TDX quotes
     */
    function disableVerifyMrtd() external onlyOwner {
        toVerifyMrtd = false;
        emit VerifyMRTDDisabled();
    }

    /**
     * @notice Internal function to verify TEE measurements against registered values
     * @param quote The TEE attestation quote data
     * @param quoteVersion The version of the quote format
     * @return True if the measurement is valid, false otherwise
     */
    function _verifyMeasurement(bytes calldata quote, uint16 quoteVersion) private view returns (bool) {
        // Check if the quote is long enough to extract the TEE type
        if (quote.length <= 8) {
            return false;
        } 
        bytes4 teeType = bytes4(quote.substring(4, 4));
        if (teeType == SGX_TEE) {
            return MeasurementDao(measurementDao).verifyMeasurementSGX(quote, quoteVersion);
        } else if(teeType == TDX_TEE) {
            if (toVerifyMrtd) {
                require(MeasurementDao(measurementDao).verifyMRTD(quote, quoteVersion), MRTDValidationFailed());
            }
            return MeasurementDao(measurementDao).verifyMeasurementTDX(quote, quoteVersion);
        } else {
            return false;
        }
    }

    /**
     * @notice Internal function to verify TEE attestation proof
     * @param aggrProof The aggregated proof containing the TEE quote
     * @return _error_code Error code (0 for success, 1 for failure)
     * @return commitment The extracted commitment from the quote
     */
    function _verifyProof(bytes calldata aggrProof) private returns (uint32 _error_code, bytes32 commitment) {
        uint16 quoteVersion = SafeCast.toUint16(BELE.leBytesToBeUint(aggrProof[0:2]));
        if (toVerifyMr) {
            require(_verifyMeasurement(aggrProof, quoteVersion), MrValidationFailed());
        }
        bytes memory ecdsa256BitSignature;
        bytes memory ecdsaAttestationKey;
        bool success;
        bytes memory output;
        TEECacheVerifier CacheAttestation = TEECacheVerifier(cacheVerifierAddr);
        (ecdsa256BitSignature, ecdsaAttestationKey) = CacheAttestation.parseAttestationKey(aggrProof, quoteVersion);
        if (cacheOption && CacheAttestation.contains(ecdsaAttestationKey)) {
            (_error_code, commitment) = CacheAttestation.verifyAndAttestOnChain(
                aggrProof, ecdsa256BitSignature, ecdsaAttestationKey, quoteVersion
            );
        } else {
            AutomataDcapAttestationFee attestation = AutomataDcapAttestationFee(dcapAttestation);
            (success, output) = attestation.verifyAndAttestOnChain(aggrProof);

            if (success) {
                if (cacheOption) CacheAttestation.addKey(ecdsaAttestationKey);
                _error_code = 0;
                uint256 offset;
                if (quoteVersion == 3) {
                    offset = USER_DATA_V3_OFFSET;
                } else if (quoteVersion == 4) {
                    bytes4 teeType = bytes4(aggrProof[4:8]);
                    if (teeType == SGX_TEE) {
                        offset = USER_DATA_V3_OFFSET;
                    } else {
                        offset = USER_DATA_V4_OFFSET;
                    }
                } else if (quoteVersion == 5) {
                    offset = USER_DATA_V5_OFFSET;
                } else {
                    _error_code = 1;
                }
                if (_error_code == 0) {
                    // extract user data from output generated by dcap attestation contract
                    assembly {
                        // 0x20: skip bytes header(32 byte)
                        commitment := mload(add(output, add(offset, 0x20)))
                    }
                } else {
                    commitment = bytes32(0);
                }
            } else {
                _error_code = 1;
                commitment = bytes32(0);
            }
        }
    }
}
