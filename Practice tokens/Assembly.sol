// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


contract AssemblyStorage {
    // uint256 public value;
    event setter(uint256);


    function setValue(uint256 _value) public {
        assembly {
            sstore(0x0, _value) //0x0 is the first slot at which we are storing the variable _value
        }
        emit setter(_value);
    }

    function getValue() public view returns (uint256 result) {
        // uint256 result;
        assembly {
            result := sload(0x0) // and here we are setting the 0x0 to the result variable 
        }
        return result;
    }
}