// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@onchain-id/solidity/contracts/interface/IIdentity.sol";

contract IRSStorage {
    // struct containing the identity contract and the country of the user
    struct Identity {
        IIdentity identityContract;
        uint16 investorCountry;
    }
    // mapping between a user address and the corresponding identity
    mapping(address => Identity) internal _identities;

    //array of Identity Registries linked to this storage
    address[] internal _identityRegistries;

   
    uint256[49] private __gap;
}
