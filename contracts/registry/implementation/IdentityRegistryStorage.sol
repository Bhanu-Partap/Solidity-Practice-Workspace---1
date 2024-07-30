// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@onchain-id/solidity/contracts/interface/IIdentity.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interface/IIdentityRegistryStorage.sol";
import "../storage/IRSStorage.sol";

contract IdentityRegistryStorage is
    IIdentityRegistryStorage,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    IRSStorage
{
    bytes32 public constant AGENT_ROLE =
        0xcab5a0bfe0b79d2c4b1c2e02599fa044d115b7511f9659307cb4276950967709;

    bytes32 public constant OWNER_ROLE =
        0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e;

    function init() external initializer {
        _grantRole(bytes32(0), _msgSender());

        _grantRole(OWNER_ROLE, _msgSender());

        _grantRole(AGENT_ROLE, _msgSender());
        __Ownable_init();
    }

    /**
     *  @dev See {IIdentityRegistryStorage-addIdentityToStorage}.
     */
    function addIdentityToStorage(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddress != address(0) && address(_identity) != address(0),
            "invalid argument - zero address"
        );
        require(
            address(_identities[_userAddress].identityContract) == address(0),
            "address stored already"
        );
        _identities[_userAddress].identityContract = _identity;
        _identities[_userAddress].investorCountry = _country;
        emit IdentityStored(_userAddress, _identity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-modifyStoredIdentity}.
     */
    function modifyStoredIdentity(address _userAddress, IIdentity _identity)
        external
        override
        onlyRole(AGENT_ROLE)
    {
        require(
            _userAddress != address(0) && address(_identity) != address(0),
            "invalid argument - zero address"
        );
        require(
            address(_identities[_userAddress].identityContract) != address(0),
            "address not stored yet"
        );
        IIdentity oldIdentity = _identities[_userAddress].identityContract;
        _identities[_userAddress].identityContract = _identity;
        emit IdentityModified(oldIdentity, _identity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-modifyStoredInvestorCountry}.
     */
    function modifyStoredInvestorCountry(address _userAddress, uint16 _country)
        external
        override
        onlyRole(AGENT_ROLE)
    {
        require(_userAddress != address(0), "invalid argument - zero address");
        require(
            address(_identities[_userAddress].identityContract) != address(0),
            "address not stored yet"
        );
        _identities[_userAddress].investorCountry = _country;
        emit CountryModified(_userAddress, _country);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-removeIdentityFromStorage}.
     */
    function removeIdentityFromStorage(address _userAddress)
        external
        override
        onlyRole(AGENT_ROLE)
    {
        require(_userAddress != address(0), "invalid argument - zero address");
        require(
            address(_identities[_userAddress].identityContract) != address(0),
            "address not stored yet"
        );
        IIdentity oldIdentity = _identities[_userAddress].identityContract;
        delete _identities[_userAddress];
        emit IdentityUnstored(_userAddress, oldIdentity);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-bindIdentityRegistry}.
     */
    function bindIdentityRegistry(address _identityRegistry) external override {
        require(
            _identityRegistry != address(0),
            "invalid argument - zero address"
        );
        require(
            _identityRegistries.length < 300,
            "cannot bind more than 300 IR to 1 IRS"
        );
        _grantRole(AGENT_ROLE, _identityRegistry);
        _identityRegistries.push(_identityRegistry);
        emit IdentityRegistryBound(_identityRegistry);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-unbindIdentityRegistry}.
     */
    function unbindIdentityRegistry(address _identityRegistry)
        external
        override
    {
        require(
            _identityRegistry != address(0),
            "invalid argument - zero address"
        );
        require(
            _identityRegistries.length > 0,
            "identity registry is not stored"
        );
        uint256 length = _identityRegistries.length;
        for (uint256 i = 0; i < length; i++) {
            if (_identityRegistries[i] == _identityRegistry) {
                _identityRegistries[i] = _identityRegistries[length - 1];
                _identityRegistries.pop();
                break;
            }
        }
        _revokeRole(AGENT_ROLE, _identityRegistry);
        emit IdentityRegistryUnbound(_identityRegistry);
    }

    /**
     *  @dev See {IIdentityRegistryStorage-linkedIdentityRegistries}.
     */
    function linkedIdentityRegistries()
        external
        view
        override
        returns (address[] memory)
    {
        return _identityRegistries;
    }

    /**
     *  @dev See {IIdentityRegistryStorage-storedIdentity}.
     */
    function storedIdentity(address _userAddress)
        external
        view
        override
        returns (IIdentity)
    {
        return _identities[_userAddress].identityContract;
    }

    /**
     *  @dev See {IIdentityRegistryStorage-storedInvestorCountry}.
     */
    function storedInvestorCountry(address _userAddress)
        external
        view
        override
        returns (uint16)
    {
        return _identities[_userAddress].investorCountry;
    }
}
