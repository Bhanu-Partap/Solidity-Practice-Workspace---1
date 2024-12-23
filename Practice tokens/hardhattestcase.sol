// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

contract Token{
    string public name = "Hardhat things";
    string public symbol= "HTX";
    uint public totalsupply = 10000;
    
    address public owner;
    mapping(address => uint) balances;

    constructor(){
        balances[msg.sender] = totalsupply;
        owner = msg.sender;
    }

    function transfer(address to, uint amount) external {
        require(balances[msg.sender]>= amount,"Not enought Tokens");
        balances[msg.sender] -= amount;
        balances[to]+= amount;
    }

    function balanceOf(address account) external view returns(uint256){
        return balances[account];
    }
    function total_Supply() external view returns(uint256){
        return balances[msg.sender];
    }

    function contractAddress() external view returns(address){
        return address(this);
    }

}

