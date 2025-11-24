// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @custom:security-contact enxi.zys@antgroup.com
contract L1GasOracle is OwnableUpgradeable {
    uint256 public l1FeePerByte;

    // the fee of da for last batch
    uint256 public lastBatchDaFee;

    // the fee of commit and verify for last batch
    uint256 public lastBatchExecFee;

    // the tx length of all tx in last batch
    uint256 public lastBatchByteLength;

    // The changing trend of the current block base fee and blob base fee compared to the previous batch
    uint256 public blobBaseFeeScala;
    uint256 public baseFeeScala;

    // the constant profit of one batch
    uint256 public l1Profit;

    // the constant parameter for the whole fee of L1
    uint256 public totalScala;

    // relayer is who can send L1 fee to jovay
    mapping(address relayerAddress => bool) public isRelayer;

    // the lower limit of tx length in one batch
    uint256 private constant MIN_TX_LENGTH_LIMIT = 6 * 128 * 1024;

    // the max limit of tx length in one batch
    uint256 private constant MAX_TX_LENGTH_LIMIT = 1e9;

    // the upper limit of L1 base fee
    uint256 private constant MAX_L1_BASE_FEE_LIMIT = 1e9;

    // the upper limit of L1 blob base fee
    uint256 private constant MAX_L1_BLOB_BASE_FEE_LIMIT = 1e9;

    // the upper limit of the sum of commit and verify tx's gas used;
    uint256 public maxL1ExecGasUsedLimit;

    // the max limit of blob gas used, mainnet is 6blobs;
    uint256 public maxL1BlobGasUsedLimit;

    // the min limit of tx length in one batch
    uint256 public minBatchTxLength;

    uint256 internal constant DEFAULT_MAX_L1_EXEC_GAS_USED = 1e6;
    uint256 internal constant DEFAULT_MAX_L1_BLOB_GAS_USED = 6 * 128 * 1024;
    uint256 internal constant DEFAULT_TOTAL_SCALA = 10;
    uint256 internal constant DEFAULT_BLOB_BASE_FEE_SCALA = 100;
    uint256 internal constant DEFAULT_BASE_FEE_SCALA = 100;
    uint256 internal constant DEFAULT_MIN_BATCH_TX_LENGTH = MIN_TX_LENGTH_LIMIT * 100;
    uint256 internal constant DEFAULT_PERCENT = 100;

    constructor(){
        _disableInitializers();
    }

    function initialize(uint256 _lastBatchDaFee, uint256 _lastBatchExecFee, uint256 _lastBatchByteLength)
        external
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        lastBatchDaFee = _lastBatchDaFee;
        lastBatchExecFee = _lastBatchExecFee;
        lastBatchByteLength = _lastBatchByteLength;
        minBatchTxLength = DEFAULT_MIN_BATCH_TX_LENGTH;
        maxL1ExecGasUsedLimit = DEFAULT_MAX_L1_EXEC_GAS_USED;
        maxL1BlobGasUsedLimit = DEFAULT_MAX_L1_BLOB_GAS_USED;
        totalScala = DEFAULT_TOTAL_SCALA;
        blobBaseFeeScala = DEFAULT_BLOB_BASE_FEE_SCALA;
        baseFeeScala = DEFAULT_BASE_FEE_SCALA;
        CalcL1FeePerByte();
        isRelayer[_msgSender()] = true;

        emit Initialized(_lastBatchDaFee, _lastBatchExecFee, _lastBatchByteLength,
            DEFAULT_MAX_L1_EXEC_GAS_USED, DEFAULT_MAX_L1_BLOB_GAS_USED,
            DEFAULT_TOTAL_SCALA, DEFAULT_BLOB_BASE_FEE_SCALA, DEFAULT_BASE_FEE_SCALA);
    }

    function CalcL1FeePerByte() internal {
        uint256 _lastBatchByteLength = lastBatchByteLength;
        if (_lastBatchByteLength < minBatchTxLength) {
            _lastBatchByteLength = minBatchTxLength;
        }
        if (_lastBatchByteLength > MAX_TX_LENGTH_LIMIT) {
            _lastBatchByteLength = MAX_TX_LENGTH_LIMIT;
        }
        uint256 _lastBatchExecFee = lastBatchExecFee * baseFeeScala / DEFAULT_PERCENT;
        if (_lastBatchExecFee > MAX_L1_BASE_FEE_LIMIT * maxL1ExecGasUsedLimit) {
            _lastBatchExecFee = MAX_L1_BASE_FEE_LIMIT * maxL1ExecGasUsedLimit;
        }
        uint256 _lastBatchDaFee = lastBatchDaFee * blobBaseFeeScala / DEFAULT_PERCENT;
        if (_lastBatchDaFee > MAX_L1_BLOB_BASE_FEE_LIMIT * maxL1BlobGasUsedLimit) {
            _lastBatchDaFee = MAX_L1_BLOB_BASE_FEE_LIMIT * maxL1BlobGasUsedLimit;
        }
        l1FeePerByte = (_lastBatchDaFee + _lastBatchExecFee + l1Profit) / _lastBatchByteLength;
        l1FeePerByte = l1FeePerByte * totalScala / DEFAULT_PERCENT;
    }

    modifier onlyRelayer() {
        // @note In the decentralized mode, it should be only called by a list of validator.
        require(isRelayer[_msgSender()], "INVALID_PERMISSION : sender is not relayer");
        _;
    }

    event SetNewBatchBlobFeeAndTxFee(uint256 _lastBatchDaFee, uint256 _lastBatchExecFee, uint256 _lastBatchByteLength);

    event SetBlobBaseFeeScalaAndTxFeeScala(uint256 _baseFeeScala, uint256 _blobBaseFeeScala);

    event SetL1Profit(uint256 _l1Profit);

    event SetTotalScala(uint256 _totalScala);

    event SetMaxL1ExecGasUsedLimit(uint256 _maxL1ExecGasUsedLimit);

    event SetMaxL1BlobGasUsedLimit(uint256 _maxL1BlobGasUsedLimit);

    event SetMinBatchTxLength(uint256 _minBatchTxLength);

    event AddRelayer(address relayer);

    event RemoveRelayer(address oldRelayer);

    event Initialized(uint256 lastBatchDaFee, uint256 lastBatchExecFee, uint256 lastBatchByteLength,
        uint256 maxL1ExecGasUsedLimit, uint256 maxL1BlobGasUsedLimit,
        uint256 totalScala, uint256 blobBaseFeeScala, uint256 baseFeeScala);

    function setNewBatchBlobFeeAndTxFee(
        uint256 _lastBatchDaFee,
        uint256 _lastBatchExecFee,
        uint256 _lastBatchByteLength
    ) external onlyRelayer {
        lastBatchByteLength = _lastBatchByteLength;
        lastBatchDaFee = _lastBatchDaFee;
        lastBatchExecFee = _lastBatchExecFee;
        CalcL1FeePerByte();

        emit SetNewBatchBlobFeeAndTxFee(_lastBatchDaFee, _lastBatchExecFee, _lastBatchByteLength);
    }

    function setBlobBaseFeeScalaAndTxFeeScala(
        uint256 _baseFeeScala,
        uint256 _blobBaseFeeScala
    ) external onlyRelayer {
        require(_baseFeeScala != 0 && _blobBaseFeeScala != 0, "scala must not be zero");
        baseFeeScala = _baseFeeScala;
        blobBaseFeeScala = _blobBaseFeeScala;
        CalcL1FeePerByte();
        emit SetBlobBaseFeeScalaAndTxFeeScala(_baseFeeScala, _blobBaseFeeScala);
    }

    function setL1Profit(uint256 _l1Profit) external onlyOwner {
        l1Profit = _l1Profit;
        CalcL1FeePerByte();

        emit SetL1Profit(_l1Profit);
    }

    function setTotalScala(uint256 _totalScala) external onlyOwner {
        totalScala = _totalScala;
        CalcL1FeePerByte();

        emit SetTotalScala(_totalScala);
    }

    function setMaxL1ExecGasUsedLimit(uint256 _maxL1ExecGasUsedLimit) external onlyOwner {
        maxL1ExecGasUsedLimit = _maxL1ExecGasUsedLimit;
        CalcL1FeePerByte();

        emit SetMaxL1ExecGasUsedLimit(_maxL1ExecGasUsedLimit);
    }

    function setMaxL1BlobGasUsedLimit(uint256 _maxL1BlobGasUsedLimit) external onlyOwner {
        maxL1BlobGasUsedLimit = _maxL1BlobGasUsedLimit;
        CalcL1FeePerByte();

        emit SetMaxL1BlobGasUsedLimit(_maxL1BlobGasUsedLimit);
    }

    function setMinBatchTxLength(uint256 _minBatchTxLength) external onlyOwner {
        minBatchTxLength = _minBatchTxLength;
        CalcL1FeePerByte();

        emit SetMinBatchTxLength(_minBatchTxLength);
    }

    function addRelayer(address _newRelayer) external onlyOwner {
        require(_newRelayer != address(0), "invalid address");
        if (!isRelayer[_newRelayer]) {
            isRelayer[_newRelayer] = true;
            emit AddRelayer(_newRelayer);
        }
    }

    function removeRelayer(address _oldRelayer) external onlyOwner {
        require(_oldRelayer != address(0), "invalid address");
        if (isRelayer[_oldRelayer]) {
            isRelayer[_oldRelayer] = false;
            emit RemoveRelayer(_oldRelayer);
        }
    }

    function getTxL1Fee(uint256 txLength) external view returns (uint256) {
        return l1FeePerByte * txLength;
    }
}
