// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract target {

    uint256[] private value;

    constructor(uint256[] memory _value) {
        value = _value;
    }

    function getValue() public view returns(uint256 [] memory){
        return value;
    }

    function changeValue(uint256 [] memory _value) public {
        value = _value;
    }

}

contract staticcall{

    function getValueFromOtherContract(address _contractAddress) public view returns (uint256){
        (bool success,bytes memory data) = _contractAddress.staticcall(abi.encodeWithSignature("getValue()"));     
        require(success , "Value Fetching Failed !");  

        uint256 val = abi.decode(data,(uint256));
        return val;
    }

}