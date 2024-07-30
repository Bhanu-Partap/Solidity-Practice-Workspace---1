// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/Initializable.sol";

contract factoryIdproxy is Initializable,Ownable  {
    constructor(address IDfactoryaddress, address _admin) {
        _storeImplementationAuthority(IDfactoryaddress);

        (bool success, ) = IDfactoryaddress.delegatecall(
            abi.encodeWithSignature("initialize(address)",_admin)
        );
       require(success, "Initialization failed.");
    }

    function setImplementationAuthority(address _newImplementation) external onlyOwner{
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


// pragma solidity 0.8.20;
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// contract factoryIdproxy is Initializable,Ownable  {
//     constructor(address IdFactoryAddress, address _admin) Ownable(msg.sender) {
//         require(IdFactoryAddress != address(0), "Invalid factory address");
//         require(_admin != address(0), "Invalid admin address");
//         _storeImplementationAuthority(IdFactoryAddress);

//         (bool success, ) = IdFactoryAddress.delegatecall(
//             abi.encodeWithSignature("initialize(address)",_admin)
//         );
//        require(success, "Initialization failed.");
//     }

//     function setImplementationAuthority(address _newImplementation) external onlyOwner{
//         _storeImplementationAuthority(_newImplementation);
//     }

//     function getImplementationAuthority() public view returns (address) {
//         address implemAuth;

//         assembly {
//             implemAuth := sload(
//                 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7
//             )
//         }
//         return implemAuth;
//     }

//     function _storeImplementationAuthority(address implementationAuthority)
//         internal
//     {
//         assembly {
//             sstore(
//                 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7,
//                 implementationAuthority
//             )
//         }
//     }

//     // solhint-disable-next-line no-complex-fallback
//     fallback() external {
//         address logic = getImplementationAuthority();
//         // solhint-disable-next-line no-inline-assembly
//         assembly {
//             calldatacopy(0x0, 0x0, calldatasize())
//             let success := delegatecall(
//                 sub(gas(), 10000),
//                 logic,
//                 0x0,
//                 calldatasize(),
//                 0,
//                 0
//             )
//             let retSz := returndatasize()
//             returndatacopy(0, 0, retSz)
//             switch success
//             case 0 {
//                 revert(0, retSz)
//             }
//             default {
//                 return(0, retSz)
//             }
//         }
//     }
// }