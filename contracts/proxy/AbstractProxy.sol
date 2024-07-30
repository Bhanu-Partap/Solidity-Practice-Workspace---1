// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./IProxy.sol";
import "../factory/Ifactory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract AbstractProxy is IProxy, Initializable {
     //event ram(address _contractaddress);
    function setImplementationAuthority(address _newImplementationAuthority)
        external
        override
    {
        require(
            msg.sender == getImplementationAuthority(),
            "only current implementationAuthority can call"
        );
        require(
            _newImplementationAuthority != address(0),
            "invalid argument - zero address"
        );

        _storeImplementationAuthority(_newImplementationAuthority);
           //emit ram(logic);
        emit ImplementationAuthoritySet(_newImplementationAuthority);

    }

    function getImplementationAuthority()
        public
        view
        override
        returns (address)
    {
        address implemAuth;

        assembly {
            implemAuth := sload(
                0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7
            )
        }
        return implemAuth;
    }

    function _storeImplementationAuthority(address implementationAuthority)
        internal
    {
        assembly {
            sstore(
                0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7,
                implementationAuthority
            )
        }
    }

    function getslot() public pure returns (bytes32) {
        return bytes32(uint256(keccak256("eip1967.proxy.name")) - 1);
    }
}
