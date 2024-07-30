// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Beacon is Ownable {
    address private implementation;

    event ImplementationChanged(address indexed newImplementation);

    constructor(address _implementation) Ownable(msg.sender) {
        implementation = _implementation;
    }

    function getImplementation() external view returns (address) {
        return implementation;
    }

    function setImplementation(address _implementation) external onlyOwner {
        implementation = _implementation;
        emit ImplementationChanged(_implementation);
    }
}
