// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@onchain-id/solidity/contracts/ClaimIssuer.sol";

contract ClaimIssuers is ClaimIssuer{
    constructor( address initialManagementKey ) ClaimIssuer(initialManagementKey){

    }
}