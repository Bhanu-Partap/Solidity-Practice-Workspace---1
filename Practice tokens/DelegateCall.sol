// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract A {

    uint public num;
    uint public value;
    address public sender;

    function updateVars(uint _num) public payable  {
        num = _num;
        value = msg.value;
        sender = msg.sender;
    }

}

contract B {

    uint public num;
    uint public value;
    address public sender;

    function updateVars(address _contract, uint _num) public payable {
        (bool success, ) = _contract.delegatecall(abi.encodeWithSignature("updateVars(uint256)", _num));
        require(success, "Passing failed");
    }

}