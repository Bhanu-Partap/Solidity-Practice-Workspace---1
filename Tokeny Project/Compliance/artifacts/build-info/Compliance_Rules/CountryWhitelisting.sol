// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";

abstract contract CountryWhitelisting is Compliance {

/// Mapping between country and their whitelist status
    mapping(uint256 => bool) private _whitelistedCountries;

    event WhitelistedCountry(uint256 _country);

    event UnWhitelistedCountry(uint256 _country);

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
}