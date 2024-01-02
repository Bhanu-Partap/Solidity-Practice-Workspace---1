// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../IModularCompliance.sol";
import "./AbstractModule.sol";

contract CountryRestrictModule is AbstractModule {

// Mapping between country and their restriction status per compliance contract
    mapping(address => mapping(uint16 => bool)) private _restrictedCountries;

    event AddedRestrictedCountry(address indexed _compliance, uint16 _country);

    event RemovedRestrictedCountry(address indexed _compliance, uint16 _country);

    function addCountryRestriction(uint16 _country) external onlyComplianceCall {
        require((_restrictedCountries[msg.sender])[_country] == false, "country already restricted");
        (_restrictedCountries[msg.sender])[_country] = true;
        emit AddedRestrictedCountry(msg.sender, _country);
    }

    function removeCountryRestriction(uint16 _country) external onlyComplianceCall {
        require((_restrictedCountries[msg.sender])[_country] == true, "country not restricted");
        (_restrictedCountries[msg.sender])[_country] = false;
        emit RemovedRestrictedCountry(msg.sender, _country);
    }

    function batchRestrictCountries(uint16[] calldata _countries) external onlyComplianceCall {
        require(_countries.length < 195, "maximum 195 can be restricted in one batch");
        for (uint256 i = 0; i < _countries.length; i++) {
            require((_restrictedCountries[msg.sender])[_countries[i]] == false, "country already restricted");
            (_restrictedCountries[msg.sender])[_countries[i]] = true;
            emit AddedRestrictedCountry(msg.sender, _countries[i]);
        }
    }

    function batchUnrestrictCountries(uint16[] calldata _countries) external onlyComplianceCall {
        require(_countries.length < 195, "maximum 195 can be unrestricted in one batch");
        for (uint256 i = 0; i < _countries.length; i++) {
            require((_restrictedCountries[msg.sender])[_countries[i]] == true, "country not restricted");
            (_restrictedCountries[msg.sender])[_countries[i]] = false;
            emit RemovedRestrictedCountry(msg.sender, _countries[i]);
        }
    }

    function moduleTransferAction(address _from, address _to, uint256 _value) external override onlyComplianceCall {}

    function moduleMintAction(address _to, uint256 _value) external override onlyComplianceCall {}

    function moduleBurnAction(address _from, uint256 _value) external override onlyComplianceCall {}

    function moduleCheck(
        address /*_from*/,
        address _to,
        uint256 /*_value*/,
        address _compliance
    ) external view override returns (bool) {
        uint16 receiverCountry = _getCountry(_compliance, _to);
        if (isCountryRestricted(_compliance, receiverCountry)) {
            return false;
        }
        return true;
    }

    function isCountryRestricted(address _compliance, uint16 _country) public view
    returns (bool) {
        return ((_restrictedCountries[_compliance])[_country]);
    }

    function _getCountry(address _compliance, address _userAddress) internal view returns (uint16) {
        return IToken(IModularCompliance(_compliance).getTokenBound()).identityRegistry().investorCountry(_userAddress);
    }
}