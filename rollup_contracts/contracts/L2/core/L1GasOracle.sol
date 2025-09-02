// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract L1GasOracle is OwnableUpgradeable{
    uint256 public l1FeePerByte;

    // L1 batch submission related parameters.
    uint256 public lastBatchDaFee;
    uint256 public lastBatchExecFee;
    uint256 public lastBatchByteLength;

    // L1 basefee and blobbasefee trend
    uint256 public blobBaseFeeScala;
    uint256 public baseFeeScala;

    // fixed income
    uint256 public l1Profit;

    // Fixed expansion factor, used to control L1 Fee overall to avoid losses, default is 1.1.
    uint256 public totalScala;

    // Permission control
    mapping(address => bool) public isRelayer;

    uint256 public txLengthLimit;

    function initialize(uint256 _lastBatchDaFee, uint256 _lastBatchExecFee, uint256 _lastBatchByteLength) external initializer {
        OwnableUpgradeable.__Ownable_init();
        totalScala = 110;
        l1Profit = 0;
        lastBatchDaFee = _lastBatchDaFee;
        lastBatchExecFee = _lastBatchExecFee;
        txLengthLimit = 50000;
        lastBatchByteLength = 50000;
        if (_lastBatchByteLength < txLengthLimit) {
            lastBatchByteLength = txLengthLimit;
        } else {
            lastBatchByteLength = _lastBatchByteLength;
        }
        blobBaseFeeScala = 100;
        baseFeeScala = 100;
        CalcL1FeePerByte();
        isRelayer[_msgSender()] = true;
    }

    function CalcL1FeePerByte() internal {
        l1FeePerByte = (((lastBatchDaFee * blobBaseFeeScala / 100) + (lastBatchExecFee * baseFeeScala / 100) + l1Profit) / lastBatchByteLength);
        l1FeePerByte = l1FeePerByte * totalScala / 100;
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

    event AddRelayer(address relayer);

    event RemoveRelayer(address oldRelayer);

    function setNewBatchBlobFeeAndTxFee(uint256 _lastBatchDaFee,
        uint256 _lastBatchExecFee,
        uint256 _lastBatchByteLength) onlyRelayer external {
        if (_lastBatchByteLength < txLengthLimit) {
            lastBatchByteLength = txLengthLimit;
        } else {
            lastBatchByteLength = _lastBatchByteLength;
        }
        lastBatchDaFee = _lastBatchDaFee;
        lastBatchExecFee = _lastBatchExecFee;
        CalcL1FeePerByte();

        emit SetNewBatchBlobFeeAndTxFee(lastBatchDaFee, lastBatchExecFee, lastBatchByteLength);
    }

    function setBlobBaseFeeScalaAndTxFeeScala(uint256 _baseFeeScala,
        uint256 _blobBaseFeeScala) onlyRelayer external {
        baseFeeScala = _baseFeeScala;
        blobBaseFeeScala = _blobBaseFeeScala;
        CalcL1FeePerByte();
        emit SetBlobBaseFeeScalaAndTxFeeScala(baseFeeScala, blobBaseFeeScala);
    }

    function setL1Profit(uint256 _l1Profit) onlyOwner external {
        l1Profit = _l1Profit;
        CalcL1FeePerByte();

        emit SetL1Profit(l1Profit);
    }

    function setTotalScala(uint256 _totalScala) onlyOwner external {
        totalScala = _totalScala;
        CalcL1FeePerByte();

        emit SetTotalScala(totalScala);
    }

    function addRelayer(address _newRelayer) onlyOwner external {
        isRelayer[_newRelayer] = true;

        emit AddRelayer(_newRelayer);
    }

    function removeRelayer(address _oldRelayer) onlyOwner external {
        isRelayer[_oldRelayer] = false;

        emit RemoveRelayer(_oldRelayer);
    }

    function getTxL1Fee(uint256 txLength) external view returns(uint256){
        return (((lastBatchDaFee + lastBatchExecFee)/lastBatchByteLength) * txLength + l1Profit) * totalScala;
    }
}