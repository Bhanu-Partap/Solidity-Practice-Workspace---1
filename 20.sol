// SPDX-License-Identifier: MIT
pragma solidity 0.8.25; 

contract Test{

    function stringConcat(string memory first , string memory second) public pure  returns(string memory){
        return string(abi.encodePacked(first, "-" ,second));
    }
}