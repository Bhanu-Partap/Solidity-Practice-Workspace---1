// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Compliance.sol";

abstract contract RulesCompliance is Compliance {


// Mapping of transfersApproved
    mapping(bytes32 => bool) private _transfersApproved;
    mapping(uint256 => bool) private _restrictedCountries;
    mapping(uint256 => bool) private _whitelistedCountries;
    mapping(address => TransferCounter) public usersCounters;
    mapping (address => uint256) public IDBalance;
    
    /// Mapping for wallets tagged as exchange wallets
    mapping(address => bool) private _exchangeIDs;
    /// Mapping for users Counters
    mapping(address => mapping(address => ExchangeTransferCounter)) private _exchangeCounters;
    /// Getter for Tokens monthlyLimit
    mapping(address => uint256) private _exchangeMonthlyLimit;

   
// STRUCTS
    struct TransferCounter {
        uint256 dailyCount;
        uint256 monthlyCount;
        uint256 dailyTimer;
        uint256 monthlyTimer;
    }

    struct ExchangeTransferCounter {
        uint256 monthlyCount;
        uint256 monthlyTimer;
    }

//Global Variable
    uint256 public dailyLimit;
    uint256 public monthlyLimit;
    uint256 public maxBalance;
    uint256 public supplyLimit;

//Approve Transfer Events
    event TransferApproved(address _from, address _to, uint _amount, address _token);
    event ApprovalRemoved(address _from, address _to, uint _amount, address _token);


//CountryRestrictions Events
    event AddedRestrictedCountry(uint256 _country);
    event RemovedRestrictedCountry(uint256 _country);


//WhitelistCountry events
    event WhitelistedCountry(uint256 _country);
    event UnWhitelistedCountry(uint256 _country);

//DayMonthLimit events
    event DailyLimitUpdated(uint _newDailyLimit);
    event MonthlyLimitUpdated(uint _newMonthlyLimit);

//ExchangeMonthlyLimits events
    event ExchangeMonthlyLimitUpdated(address _exchangeID, uint _newExchangeMonthlyLimit);
    event ExchangeIDAdded(address _newExchangeID);
    event ExchangeIDRemoved(address _exchangeID);

//MaxBalance event
    event MaxBalanceSet(uint256 _maxBalance);

//SuppliLimit events
    event SupplyLimitSet(uint256 _limit);

  function removeApproval(address _from, address _to, uint _amount) external onlyAdmin {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        require(_transfersApproved[transferId], "transfer not approved yet");
        _transfersApproved[transferId] = false;
        emit ApprovalRemoved(_from, _to, _amount, address(tokenBound));
    }

    function approveAndTransfer(address _from, address _to, uint _amount) external {
        approveTransfer(_from, _to, _amount);
        tokenBound.transferFrom(_from, _to, _amount);
    }

    function approveTransfer(address _from, address _to, uint _amount) public onlyAdmin {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        require(!_transfersApproved[transferId], "transfer already approved");
        _transfersApproved[transferId] = true;
        emit TransferApproved(_from, _to, _amount, address(tokenBound));
    }

    function complianceCheckOnApproveTransfer(address _from, address _to, uint256 _value) public view returns (bool) {
        if (!isTokenAgent(_from)) {
            bytes32 transferId = _calculateTransferID (_from, _to, _value, address(tokenBound));
            if (!_transfersApproved[transferId]){
                return false;
            }
        }
        return true;
    }

    function _transferActionOnApproveTransfer(address _from, address _to, uint256 _value) internal {
        _transferProcessed(_from, _to, _value);
    }

    function _creationActionOnApproveTransfer(address _to, uint256 _value) internal {}

    function _destructionActionOnApproveTransfer(address _from, uint256 _value) internal {}

    function _transferProcessed(address _from, address _to, uint _amount) internal {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        if (_transfersApproved[transferId]) {
            _transfersApproved[transferId] = false;
            emit ApprovalRemoved(_from, _to, _amount, address(tokenBound));
        }
    }

    function _calculateTransferID (
        address _from,
        address _to,
        uint _amount,
        address _token
    ) internal pure returns (bytes32){
        bytes32 transferId = keccak256(abi.encode(_from, _to, _amount, _token));
        return transferId;
    }

    function batchRestrictCountries(uint256[] calldata _countries) external {
        for (uint i = 0; i < _countries.length; i++) {
            addCountryRestriction(_countries[i]);
        }
    }

    function batchUnrestrictCountries(uint256[] calldata _countries) external {
        for (uint i = 0; i < _countries.length; i++) {
            removeCountryRestriction(_countries[i]);
        }
    }

    function addCountryRestriction(uint256 _country) public onlyOwner {
        require(!_restrictedCountries[_country], "country already restricted");
        _restrictedCountries[_country] = true;
        emit AddedRestrictedCountry(_country);
    }

    function removeCountryRestriction(uint256 _country) public onlyOwner {
        require(_restrictedCountries[_country], "country not restricted");
        _restrictedCountries[_country] = false;
        emit RemovedRestrictedCountry(_country);
    }

    function isCountryRestricted(uint256 _country) public view returns (bool) {
        return (_restrictedCountries[_country]);
    }


    function complianceCheckOnCountryRestrictions (address /*_from*/, address _to, uint256 /*_value*/)
    public view returns (bool) {
        uint256 receiverCountry = _getCountry(_to);
        if (isCountryRestricted(receiverCountry)) {
            return false;
        }
        return true;
    }

    function _transferActionOnCountryRestrictions(address _from, address _to, uint256 _value) internal {}

    function _creationActionOnCountryRestrictions(address _to, uint256 _value) internal {}

    function _destructionActionOnCountryRestrictions(address _from, uint256 _value) internal {}

    
//WhitelistingCountry Functions

    function batchWhitelistCountries(uint256[] memory _countries) external {
        for (uint i = 0; i < _countries.length; i++) {
            whitelistCountry(_countries[i]);
        }
    }

    function batchUnWhitelistCountries(uint256[] memory _countries) external {
        for (uint i = 0; i < _countries.length; i++) {
            unWhitelistCountry(_countries[i]);
        }
    }

    function whitelistCountry(uint256 _country) public onlyOwner {
        require(!_whitelistedCountries[_country], "country already whitelisted");
        _whitelistedCountries[_country] = true;
        emit WhitelistedCountry(_country);
    }

    function unWhitelistCountry(uint256 _country) public onlyOwner {
        require(_whitelistedCountries[_country], "country not whitelisted");
        _whitelistedCountries[_country] = false;
        emit UnWhitelistedCountry(_country);
    }

    function isCountryWhitelisted(uint256 _country) public view returns (bool) {
        return (_whitelistedCountries[_country]);
    }

    function complianceCheckOnCountryWhitelisting (address /*_from*/, address _to, uint256 /*_value*/)
    public view returns (bool) {
        uint256 receiverCountry = _getCountry(_to);
        if (isCountryWhitelisted(receiverCountry)) {
            return true;
        }
        return false;
    }

    function _transferActionOnCountryWhitelisting(address _from, address _to, uint256 _value) internal {}

    function _creationActionOnCountryWhitelisting(address _to, uint256 _value) internal {}

    function _destructionActionOnCountryWhitelisting(address _from, uint256 _value) internal {}

//DayMonthLimit Functions

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


//ExchangeMonthlyLimits functions

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

    // solhint-disable-next-line no-empty-blocks
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


//MaxBalance functions

    function setMaxBalance(uint256 _max) external onlyOwner {
        maxBalance = _max;
        emit MaxBalanceSet(_max);
    }

    function complianceCheckOnMaxBalance (address /*_from*/, address _to, uint256 _value) public view returns (bool) {
        if (_value > maxBalance) {
            return false;
        }
        address _id = _getIdentity(_to);
        if ((IDBalance[_id] + _value) > maxBalance) {
            return false;
        }
        return true;
    }

    function _transferActionOnMaxBalance(address _from, address _to, uint256 _value) internal {
        address _idFrom = _getIdentity(_from);
        address _idTo = _getIdentity(_to);
        IDBalance[_idTo] += _value;
        IDBalance[_idFrom] -= _value;
        require (IDBalance[_idTo] <= maxBalance, "post-transfer balance too high");
    }

    function _creationActionOnMaxBalance(address _to, uint256 _value) internal {
        address _idTo = _getIdentity(_to);
        IDBalance[_idTo] += _value;
        require (IDBalance[_idTo] <= maxBalance, "post-minting balance too high");
    }

    function _destructionActionOnMaxBalance(address _from, uint256 _value) internal {
        address _idFrom = _getIdentity(_from);
        IDBalance[_idFrom] -= _value;
    }


//SuppliLimit Functions

    function setSupplyLimit(uint256 _limit) external onlyOwner {
        supplyLimit = _limit;
        emit SupplyLimitSet(_limit);
    }

    function complianceCheckOnSupplyLimit (address /*_from*/, address /*_to*/, uint256 /*_value*/)
    public view returns (bool) {
        return true;
    }

    function _transferActionOnSupplyLimit(address _from, address _to, uint256 _value) internal {}

    function _creationActionOnSupplyLimit(address /*_to*/, uint256 /*_value*/) internal {
        require(tokenBound.totalSupply() <= supplyLimit, "cannot mint more tokens");
    }

    function _destructionActionOnSupplyLimit(address _from, uint256 _value) internal {}

}
