// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../IModularCompliance.sol";
import "./AbstractModule.sol";

contract CountryAllowModule is AbstractModule {
    // Mapping between country and their allowance status per compliance contract
    mapping(address => mapping(uint16 => bool)) private _allowedCountries;

    // events

    event CountryAllowed(address _compliance, uint16 _country);

    event CountryUnallowed(address _compliance, uint16 _country);

    // Custom Errors
    error CountryAlreadyAllowed(address _compliance, uint16 _country);
    error CountryNotAllowed(address _compliance, uint16 _country);

    // functions

    function batchAllowCountries(uint16[] calldata _countries)
        external
        onlyComplianceCall
    {
        for (uint256 i = 0; i < _countries.length; i++) {
            (_allowedCountries[msg.sender])[_countries[i]] = true;
            emit CountryAllowed(msg.sender, _countries[i]);
        }
    }

    function batchDisallowCountries(uint16[] calldata _countries)
        external
        onlyComplianceCall
    {
        for (uint256 i = 0; i < _countries.length; i++) {
            (_allowedCountries[msg.sender])[_countries[i]] = false;
            emit CountryUnallowed(msg.sender, _countries[i]);
        }
    }

    function addAllowedCountry(uint16 _country) external onlyComplianceCall {
        if ((_allowedCountries[msg.sender])[_country] == true)
            revert CountryAlreadyAllowed(msg.sender, _country);
        (_allowedCountries[msg.sender])[_country] = true;
        emit CountryAllowed(msg.sender, _country);
    }

    function removeAllowedCountry(uint16 _country) external onlyComplianceCall {
        if ((_allowedCountries[msg.sender])[_country] == false)
            revert CountryNotAllowed(msg.sender, _country);
        (_allowedCountries[msg.sender])[_country] = false;
        emit CountryUnallowed(msg.sender, _country);
    }

    function moduleTransferAction(
        address _from,
        address _to,
        uint256 _value
    ) external override onlyComplianceCall {}

    function moduleMintAction(address _to, uint256 _value)
        external
        override
        onlyComplianceCall
    {}

    function moduleBurnAction(address _from, uint256 _value)
        external
        override
        onlyComplianceCall
    {}

    function moduleCheck(
        address, /*_from*/
        address _to,
        uint256, /*_value*/
        address _compliance
    ) external view override returns (bool) {
        uint16 receiverCountry = _getCountry(_compliance, _to);
        return isCountryAllowed(_compliance, receiverCountry);
    }

    function isCountryAllowed(address _compliance, uint16 _country)
        public
        view
        returns (bool)
    {
        return _allowedCountries[_compliance][_country];
    }

    function _getCountry(address _compliance, address _userAddress)
        internal
        view
        returns (uint16)
    {
        return
            IToken(IModularCompliance(_compliance).getTokenBound())
                .identityRegistry()
                .investorCountry(_userAddress);
    }
}
