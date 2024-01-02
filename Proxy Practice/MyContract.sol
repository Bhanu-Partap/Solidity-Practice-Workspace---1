// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./Proxiable.sol";

contract Owned is Proxiable {
    // ensures no one can manipulate this contract once it is deployed
    address public owner;
    uint public count;
    bool public initalized=  false;

    function initalize() public {
        require(owner==address(0),"already initalize");
        require(!initalized,"already initalize");
        owner = msg.sender;
        initalized= true;
    }
  
  bytes4 public x= bytes4(keccak256("initalize()"));
    function increment()public {
        count++;
    }

    function updateCode(address newCode) onlyOwner public {
        updateCodeAddress(newCode);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner is allowed to perform this action");
        _;
    }
}