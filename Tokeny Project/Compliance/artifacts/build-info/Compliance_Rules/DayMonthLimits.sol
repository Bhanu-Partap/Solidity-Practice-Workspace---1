// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";

abstract contract DayMonthLimits is Compliance {

// Struct 
    struct TransferCounter {
        uint256 dailyCount;
        uint256 monthlyCount;
        uint256 dailyTimer;
        uint256 monthlyTimer;
    }

//Global Variable
    uint256 public dailyLimit;
    uint256 public monthlyLimit;


// Mapping for users Counters
    mapping(address => TransferCounter) public usersCounters;

    event DailyLimitUpdated(uint _newDailyLimit);

    event MonthlyLimitUpdated(uint _newMonthlyLimit);

    function setDailyLimit(uint256 _newDailyLimit) external onlyOwner {
        dailyLimit = _newDailyLimit;
        emit DailyLimitUpdated(_newDailyLimit);
    }

    function setMonthlyLimit(uint256 _newMonthlyLimit) external onlyOwner {
        monthlyLimit = _newMonthlyLimit;
        emit MonthlyLimitUpdated(_newMonthlyLimit);
    }

    function complianceCheckOnDayMonthLimits(address _from, address /*_to*/, uint256 _value) public view returns (bool) {
        address senderIdentity = _getIdentity(_from);
        if (!isTokenAgent(_from)) {
            if (_value > dailyLimit) {
                return false;
            }
            if (!_isDayFinished(senderIdentity) &&
            ((usersCounters[senderIdentity].dailyCount + _value > dailyLimit)
            || (usersCounters[senderIdentity].monthlyCount + _value > monthlyLimit))) {
                return false;
            }
            if (_isDayFinished(senderIdentity) && _value + usersCounters[senderIdentity].monthlyCount > monthlyLimit) {
                return(_isMonthFinished(senderIdentity));
            }
        }
        return true;
    }

    function _transferActionOnDayMonthLimits(address _from, address /*_to*/, uint256 _value) internal {
        _increaseCounters(_from, _value);
    }

    function _creationActionOnDayMonthLimits(address _to, uint256 _value) internal {}

    function _destructionActionOnDayMonthLimits(address _from, uint256 _value) internal {}

    function _increaseCounters(address _userAddress, uint256 _value) internal {
        address identity = _getIdentity(_userAddress);
        _resetDailyCooldown(identity);
        _resetMonthlyCooldown(identity);
        if ((usersCounters[identity].dailyCount + _value) <= dailyLimit) {
            usersCounters[identity].dailyCount += _value;
        }
        if ((usersCounters[identity].monthlyCount + _value) <= monthlyLimit) {
            usersCounters[identity].monthlyCount += _value;
        }
    }

    function _resetDailyCooldown(address _identity) internal {
        if (_isDayFinished(_identity)) {
            usersCounters[_identity].dailyTimer = block.timestamp + 1 days;
            usersCounters[_identity].dailyCount = 0;
        }
    }

    function _resetMonthlyCooldown(address _identity) internal {
        if (_isMonthFinished(_identity)) {
            usersCounters[_identity].monthlyTimer = block.timestamp + 30 days;
            usersCounters[_identity].monthlyCount = 0;
        }
    }

    function _isDayFinished(address _identity) internal view returns (bool) {
        return (usersCounters[_identity].dailyTimer <= block.timestamp);
    }

    function _isMonthFinished(address _identity) internal view returns (bool) {
        return (usersCounters[_identity].monthlyTimer <= block.timestamp);
    }

}