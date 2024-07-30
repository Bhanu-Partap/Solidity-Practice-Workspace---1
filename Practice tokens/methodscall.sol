// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract methods{
    uint public x= 10;

    function set(uint _x) public {
        x=_x;
    }
       function contractAddress() external view returns(address){
        return address(this);
    }
}