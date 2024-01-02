// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";

abstract contract ExchangeMonthlyLimits is Compliance {

// Struct of transfer Counters
    struct ExchangeTransferCounter {
        uint256 monthlyCount;
        uint256 monthlyTimer;
    }

//Mappings
    mapping(address => uint256) private _exchangeMonthlyLimit;

    // Mapping for users Counters
    mapping(address => mapping(address => ExchangeTransferCounter)) private _exchangeCounters;

    // Mapping for wallets tagged as exchange wallets
    mapping(address => bool) private _exchangeIDs;

    event ExchangeMonthlyLimitUpdated(address _exchangeID, uint _newExchangeMonthlyLimit);

    event ExchangeIDAdded(address _newExchangeID);

    event ExchangeIDRemoved(address _exchangeID);

    function setExchangeMonthlyLimit(address _exchangeID, uint256 _newExchangeMonthlyLimit) external onlyOwner {
        _exchangeMonthlyLimit[_exchangeID] = _newExchangeMonthlyLimit;
        emit ExchangeMonthlyLimitUpdated(_exchangeID, _newExchangeMonthlyLimit);
    }

    function addExchangeID(address _exchangeID) public onlyOwner {
        require(!isExchangeID(_exchangeID), "ONCHAINID already tagged as exchange");
        _exchangeIDs[_exchangeID] = true;
        emit ExchangeIDAdded(_exchangeID);
    }

    function removeExchangeID(address _exchangeID) public onlyOwner {
        require(isExchangeID(_exchangeID), "ONCHAINID not tagged as exchange");
        _exchangeIDs[_exchangeID] = false;
        emit ExchangeIDRemoved(_exchangeID);
    }

    function isExchangeID(address _exchangeID) public view returns (bool){
        return _exchangeIDs[_exchangeID];
    }

    function getMonthlyCounter(address _exchangeID, address _investorID) public view returns (uint256) {
        return (_exchangeCounters[_exchangeID][_investorID]).monthlyCount;
    }

    function getMonthlyTimer(address _exchangeID, address _investorID) public view returns (uint256) {
        return (_exchangeCounters[_exchangeID][_investorID]).monthlyTimer;
    }

    function getExchangeMonthlyLimit(address _exchangeID) public view returns (uint256) {
        return _exchangeMonthlyLimit[_exchangeID];
    }

    function complianceCheckOnExchangeMonthlyLimits(address _from, address _to, uint256 _value) public view returns
    (bool) {
        address senderIdentity = _getIdentity(_from);
        address receiverIdentity = _getIdentity(_to);
        if (!isTokenAgent(_from) && _from != address(0)) {
            if (isExchangeID(receiverIdentity)) {
                if(_value > _exchangeMonthlyLimit[receiverIdentity]) {
                    return false;
                }
                if (!_isExchangeMonthFinished(receiverIdentity, senderIdentity)
                && ((getMonthlyCounter(receiverIdentity, senderIdentity) + _value > _exchangeMonthlyLimit[receiverIdentity]))) {
                    return false;
                }
            }
        }
        return true;
    }

    function _transferActionOnExchangeMonthlyLimits(address _from, address _to, uint256 _value) internal {
        address senderIdentity = _getIdentity(_from);
        address receiverIdentity = _getIdentity(_to);
        if(isExchangeID(receiverIdentity) && !isTokenAgent(_from)) {
            _increaseExchangeCounters(senderIdentity, receiverIdentity, _value);
        }
    }

    function _creationActionOnExchangeMonthlyLimits(address _to, uint256 _value) internal {}

    function _destructionActionOnExchangeMonthlyLimits(address _from, uint256 _value) internal {}

    function _increaseExchangeCounters(address _exchangeID, address _investorID, uint256 _value) internal {
        _resetExchangeMonthlyCooldown(_exchangeID, _investorID);

        if ((getMonthlyCounter(_exchangeID, _investorID) + _value) <= _exchangeMonthlyLimit[_exchangeID]) {
            (_exchangeCounters[_exchangeID][_investorID]).monthlyCount += _value;
        }
    }

    function _resetExchangeMonthlyCooldown(address _exchangeID, address _investorID) internal {
        if (_isExchangeMonthFinished(_exchangeID, _investorID)) {
            (_exchangeCounters[_exchangeID][_investorID]).monthlyTimer = block.timestamp + 30 days;
            (_exchangeCounters[_exchangeID][_investorID]).monthlyCount = 0;
        }
    }

    function _isExchangeMonthFinished(address _exchangeID, address _investorID) internal view returns (bool) {
        return (getMonthlyTimer(_exchangeID, _investorID) <= block.timestamp);
    }
}