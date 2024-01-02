// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

contract Test {
    uint x=10;
    function get()public view returns(uint256){
            return x;
    } 
    function set(uint256 _x)public{
        x=_x;
    }
}