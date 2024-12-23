// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
import "hardhat/console.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/Initializable.sol";

contract factoryNFTproxy is Initializable, Ownable {
    constructor(
        address factoryaddress,
        address _admin,
        address _beaconNftUpgradable,
        address _identityFactory
    ) {
        _storeImplementationAuthority(factoryaddress);

        (bool success, ) = factoryaddress.delegatecall(
            abi.encodeWithSignature(
                "init(address,address,address)",
                _admin,
                _beaconNftUpgradable,
                _identityFactory
            )
        );
        require(success, "Initialization failed.");
    }

    function setImplementationAuthority(address _newImplementation)
        external
        onlyOwner
    {
        _storeImplementationAuthority(_newImplementation);
    }

    function getImplementationAuthority() public view returns (address) {
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

    // solhint-disable-next-line no-complex-fallback
    fallback() external {
        address logic = getImplementationAuthority();
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(
                sub(gas(), 10000),
                logic,
                0x0,
                calldatasize(),
                0,
                0
            )
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}
