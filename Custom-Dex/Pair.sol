// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Erc-20.sol";

contract Pair {

    address owner;

    struct pairdata{
        address token0;
        address token1;
        uint reserve0;
        uint reserve1;
        uint Timestamp;    
        uint id;
    }
    modifier  onlyOwner(){
    owner= msg.sender;
    _;
    }  

    erc20 token0Address = new erc20(name_,symbol_,_totalSupply);
    erc20 token1Address = new erc20(name_,symbol_,_totalSupply);

    mapping(uint=>pairdata) public tokenDetails;

    function createPair(address token0, address token1)public returns(){
        
    }

    function depositLiquidity(uint _token0, uint _token1, address _to)public returns(uint){

    }

    function withdrawLiquidity(uint _token0, uint _token1, address _to)public{

    }




}
