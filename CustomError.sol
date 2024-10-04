// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract CustomError{

    address public owner;

    error Unauthorized(address caller,address required);

    constructor (){
        owner = msg.sender;
    }

    function _unauthorize(address newOwner)public {
        if(msg.sender != owner){
            revert Unauthorized({
                caller : msg.sender,
                required: owner
            });
        }
        owner = newOwner;
    }   
}
