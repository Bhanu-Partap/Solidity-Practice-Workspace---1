// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";

abstract contract CountryRestrictions is Compliance  {

/// Mapping between country and their restriction status
    mapping(uint256 => bool) private _restrictedCountries;

    event AddedRestrictedCountry(uint256 _country);

    event RemovedRestrictedCountry(uint256 _country);

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
}