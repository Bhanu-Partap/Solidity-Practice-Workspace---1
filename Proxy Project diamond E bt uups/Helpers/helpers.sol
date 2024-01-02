// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Types.sol";

abstract contract Helper{
    // Helper Function
    // Returns right-aligned address
    function addressToBytes32(address a) public pure returns (bytes32) {
        return bytes32(uint(uint160(a)));
    }

    // Gets right-aligned address
    function bytes32ToAddress(bytes32 b) public pure returns (address) {
        return address(uint160(uint(b)));
    }

    function addressDataToBytes32(
        AddressData memory ad
    ) public pure returns (bytes32) {
        return bytes32(bytes.concat(ad.Data, bytes20(ad.Address)));
    }

    function bytes32ToAddressData(
        bytes32 b
    ) public pure returns (AddressData memory) {
        return AddressData(bytes12(b), bytes32ToAddress(b));
    }

    function addressNumberToBytes32(
        AddressNumber memory ad
    ) public pure returns (bytes32) {
        return bytes32(bytes.concat(bytes12(ad.Number), bytes20(ad.Address)));
    }

    function bytes32ToAddressNumber(
        bytes32 b
    ) public pure returns (AddressNumber memory) {
        return AddressNumber(uint96(bytes12(b)), bytes32ToAddress(b));
    }

    // Returns 52 bytes
    function createMatchCheckId(
        bytes32 _competition,
        address _player
    ) internal pure returns (bytes memory) {
        return bytes.concat(_competition, bytes20(_player));
    }

    // Returns 64 bytes - could be smaller?
    function createMatchDisputeId(
        bytes32 _competitionId,
        uint _matchIndex
    ) internal pure returns (bytes memory) {
        return bytes.concat(_competitionId, bytes32(_matchIndex));
    }

    /// Internal Functions

    // From Uniswap v2
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _calculateUnsignedPercent(
        uint _number1,
        uint8 _percent
    ) internal pure returns (uint) {
        return (_number1 * _percent) / 100;
    }

    function _calculatePercent(
        int _number1,
        uint8 _percent
    ) internal pure returns (int) {
        return (_number1 * int8(_percent)) / 100;
    }
}
