// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";


contract ERC_20{
    string public  name;
    string public  symbol;
    uint8 public  decimals;
    uint256 public totalSupply;


    //mapping
    mapping(address => uint256) balances;
    mapping(address => mapping(address=>uint256)) allowance;

    //events
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(string memory _name, string memory _symbol, uint256 _totalSupply){
        name=_name;
        symbol = _symbol;
        decimals = 18;
        totalSupply = _totalSupply;
        balances[msg.sender] = _totalSupply;
    }

    function balanceOf(address _owner) public view returns(uint256){
        require(_owner != address(0)," Not the owner");
        return balances[_owner];
    }

    function balanceO(address _owner) public view returns(uint256){
        require(_owner != address(0)," Not the owner");
        return balances[_owner];
    }

}