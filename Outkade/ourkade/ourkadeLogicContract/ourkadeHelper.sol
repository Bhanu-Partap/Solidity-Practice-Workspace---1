// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

 import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";
contract OurkadeHelper {
   
    // Gets right-aligned address
    function bytes32ToAddress(bytes32 b) public pure returns (address) {
        return ourkadelib.bytes32ToAddress(b);
    }

     function addressNumberToBytes32(
        AddressNumber memory ad
    ) public pure returns (bytes32) {
        return ourkadelib.addressNumberToBytes32(ad);
    }

    //  Returns right-aligned address
    function addressToBytes32(address a) public pure returns (bytes32) {
        return ourkadelib.addressToBytes32(a);
    }

    function addressDataToBytes32(
        AddressData memory ad
    ) public pure returns (bytes32) {
        return ourkadelib.addressDataToBytes32(ad);
    }

   

    // Returns 64 bytes - could be smaller?
    function createMatchDisputeId(
        bytes32 _competitionId,
        uint256 _matchIndex
    ) private pure returns (bytes memory) {
        return ourkadelib.createMatchDisputeId(_competitionId, _matchIndex);
    }

    function _competitionIdToOwner(
        bytes32 _competitionId
    ) private pure returns (address) {
        return ourkadelib._competitionIdToOwner(_competitionId);
    }

    function bytes32ToAddressNumber(
        bytes32 b
    ) public pure returns (AddressNumber memory) {
        return AddressNumber(uint96(bytes12(b)), bytes32ToAddress(b));
    }

    function bytes32ToAddressData(
        bytes32 b
    ) public pure returns (AddressData memory) {
        return AddressData(bytes12(b), bytes32ToAddress(b));
    }
}
