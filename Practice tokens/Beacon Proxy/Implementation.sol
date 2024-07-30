// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// contract Counter {
//     uint256 private count;

//     function increment() public {
//         count += 1;
//     }

//     function getCount() public view returns (uint256) {
//         return count;
//     }
// }



pragma solidity ^0.8.20;

contract Counter {
    uint256 private count;
    address public owner;

    // Initialization function to set the owner
    function initialize(address _owner) public {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    function increment() public {
        require(msg.sender == owner, "Only owner can increment");
        count += 1;
    }

    function getCount() public view returns (uint256) {
        return count;
    }
}

