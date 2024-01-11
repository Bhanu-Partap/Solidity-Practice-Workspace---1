// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Erc-20.sol";

contract Pair {

    address owner;
    uint pairId;

    struct pairdata{
        erc20 token0;
        erc20 token1;
        string token0Name;
        string token1Name;
        uint reserve0;
        uint reserve1;
        uint Timestamp; 
    }

    mapping(uint256=>pairdata) public pairDetails;

    modifier  onlyOwner(){
    owner= msg.sender;
    _;
    }  

    function createPair(string memory _token0Name, string memory _token0symbol, uint _token0totalSupply,string memory _token1Name, string memory _token1symbol, uint _token1totalSupply)public returns( pairdata memory ){
        erc20 token0Address= new erc20(_token0Name,_token0symbol,_token0totalSupply);
        erc20 token1Address = new erc20(_token1Name,_token1symbol,_token1totalSupply);
        // require(token0Address != token1Address,"Both tokens can't be same");
        pairId++;
        pairDetails[pairId].token0= token0Address;
        pairDetails[pairId].token1= token1Address;
        pairDetails[pairId].token0Name= _token0Name;
        pairDetails[pairId].token1Name= _token1Name;
        pairDetails[pairId].Timestamp= block.timestamp;
        pairDetails[pairId].reserve0= token0Address.balanceOf(address(this));
        pairDetails[pairId].reserve1= token1Address.balanceOf(address(this));
    }

    function depositLiquidity(uint _token0Amount, uint _token1Amount)public returns(uint){
        
    }

    // function withdrawLiquidity(uint _token0, uint _token1, address _to)public{

    // }




}
