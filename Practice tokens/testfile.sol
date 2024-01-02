// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.7;

// contract demo {
//     // uint public number;
//     uint number;

//     function setnumber(uint256 _number) public returns(uint){
//         number = _number;
//         return number;
//     }

//     function getnumber() public view returns(uint){
//         return number;
//     }
// }

pragma solidity ^0.8.7;

contract demo {
    // uint public number;
    uint number;

    function setnumber(uint256 _number) public returns(uint){
        number = _number;
        return number;
    }

    function getnumber() public view returns(uint){
        return number;
    }
}
