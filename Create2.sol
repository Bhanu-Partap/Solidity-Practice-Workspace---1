// pragma solidity ^0.8.0;

// contract MyContract {
//     address public owner;

//     constructor(address _owner) {
//         owner = _owner;
//     }
// }

// contract Factory {
//     event Deployed(address addr, bytes32 salt);

//     function deploy(bytes32 salt, address _owner) public returns (address) {
//         bytes memory bytecode = getBytecode(_owner);
//         address addr;
//         assembly {
//             addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
//         }
//         require(addr != address(0), "Failed to deploy contract");
//         emit Deployed(addr, salt);
//         return addr;
//     }

//     function getBytecode(address _owner) public pure returns (bytes memory) {
//         bytes memory bytecode = type(MyContract).creationCode;
//         return abi.encodePacked(bytecode, abi.encode(_owner));
//     }

//     function getAddress(bytes32 salt, address _owner) public view returns (address) {
//         bytes memory bytecode = getBytecode(_owner);
//         bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
//         return address(uint160(uint256(hash)));
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract DeterministicDeployFactory {
    function deployUsingCreate2(bytes memory bytecode, string memory _salt)
        external
        returns (address)
    {
        address addr;
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }

    function computeAddress(
        address deployerAddress,
        bytes32 salt,
        bytes memory initCode
    ) public pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployerAddress,
                salt,
                keccak256(initCode)
            )
        );
        return address(uint160(uint256(hash)));
    }
}
