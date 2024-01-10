// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IERC20{
    function totalSupply() external view returns(uint);
    function balanceOf(address account) external view returns(uint);
    function transfer(address recipient,uint amount) external returns(bool);

    event Transfer(address indexed from, address indexed to , uint value);

}


contract erc20 is IERC20{
    string public  name;
    string public symbol;
    uint public  decimals =18;

    event Approval(address indexed tokenOwner,address indexed spender ,uint tokens);
    

    mapping(address=>uint) balances;
    mapping(address=>mapping(address =>uint)) allowed;

    uint totalSupply_ =10000;
    address admin;
    
    constructor(string memory name_, string memory symbol_, uint totalSupply_)  {
         name=name_;
         symbol=symbol_;
         totalSupply=totalSupply_;
         balances[msg.sender]= totalSupply_;
         admin = msg.sender;

    }

    function totalSupply() public override view returns(uint){
        return totalSupply_;

    }

    function balanceOf(address tokenOwner) public override view returns(uint){
        return balances[tokenOwner];
    }

    function transfer(address receiver,uint numTokens) public override returns(bool){
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] -=numTokens;
        balances[receiver] += numTokens;
        emit Transfer(msg.sender,receiver,numTokens);
        return true;
    }

    modifier onlyAdmin{
        require(msg.sender == admin , "only admin can run this function");
        _;
    }

    function mint(uint _qty) public  onlyAdmin returns(uint){
        totalSupply += qty;
        balances[msg.sender] += _qty;
        return totalSupply_; 
    }

    function burn(uint _qty) public  onlyAdmin returns(uint){
        totalSupply -= qty;
        balances[msg.sender] -= _qty;
        return totalSupply_; 
    }

    function allowence(address owner,address spender) public view returns(uint){
        return allowed[_owner][_spender];
    }

    function approve(address spender,uint value) public returns(bool){
        allowed[msg.sender][_spender] =_value;
        emit Approval(msg.sender,_spender,_value);
        return true;
    }


    //spender will run transfer from function
    function transferFrom(address from,address to,uint _value) public returns (bool){
        uint allow = allowed[_from][msg.sender];
        require(balances[_from]>=_value && allow>=_value);
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -=_value; 
         emit Transfer(_from,_to,_value);
         return true;
        
    }
}
