// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../interface/IClaimTopicsRegistry.sol";
import "../interface/ITrustedIssuersRegistry.sol";
import "../interface/IIdentityRegistryStorage.sol";

contract IRStorage {
    // Address of the ClaimTopicsRegistry Contract
    IClaimTopicsRegistry internal _tokenTopicsRegistry;

    // Address of the TrustedIssuersRegistry Contract
    ITrustedIssuersRegistry internal _tokenIssuersRegistry;

    // Address of the IdentityRegistryStorage Contract
    IIdentityRegistryStorage internal _tokenIdentityStorage;

    
    uint256[49] private __gap;
}
