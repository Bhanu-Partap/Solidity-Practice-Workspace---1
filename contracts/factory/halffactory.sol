// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../registry/implementation/ClaimTopicsRegistry.sol";
import "../registry/implementation/IdentityRegistry.sol";
import "../registry/implementation/IdentityRegistryStorage.sol";
import "../token/token.sol";
import "../Compliance/modular/ModularCompliance.sol";
import "../registry/implementation/TrustedIssuersRegistry.sol";

contract halffactory {
    function _deploy(uint256 _salt, bytes memory bytecode)
        private
        returns (address)
    {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(_salt)));
        address addr;

        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode) // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        return addr;
    }

   

    function claimtopicregistry(uint256 _salt) public returns (address) {
        bytes memory _code = type(ClaimTopicsRegistry).creationCode;
        return _deploy(_salt, _code);
    }

    function identityregistrystorage(uint256 _salt) public returns (address) {
        bytes memory _code = type(IdentityRegistryStorage).creationCode;
        return _deploy(_salt, _code);
    }

    function identityregistry(uint256 _salt) public returns (address) {
        bytes memory _code = type(IdentityRegistry).creationCode;

        return _deploy(_salt, _code);
    }

    function modularcompliance(uint256 _salt) public returns (address) {
        bytes memory _code = type(ModularCompliance).creationCode;
        return _deploy(_salt, _code);
    }
}
