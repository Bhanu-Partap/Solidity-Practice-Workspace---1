// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Erc-20.sol";
import "./LpToken.sol";


contract Pair {

    address owner;
    uint pairId;
    erc20 token0Address;
    erc20 token1Address;
    LpTokens lptokens;

    struct pairdata{
        erc20 token0;
        erc20 token1;
        string token0Name;
        string token1Name;
        uint reserve0;
        uint reserve1;
        uint Timestamp; 
        Liquidity [] liquidity;
    }

    struct Liquidity{
        uint token0Amount;
        uint token1Amount;
        address liquidityProviderAddress;
    }

    mapping(uint256=>pairdata) public pairDetails;
    mapping(address => mapping(uint256=>Liquidity)) public liquidityProviders;

    // modifier  onlyOwner(){
    // owner= msg.sender;
    // _;
    // }  

    function createPair(string memory _token0Name, string memory _token0symbol, uint _token0totalSupply,string memory _token1Name, string memory _token1symbol, uint _token1totalSupply)public returns( pairdata memory ){
        token0Address= new erc20(_token0Name,_token0symbol,_token0totalSupply);
        token1Address = new erc20(_token1Name,_token1symbol,_token1totalSupply);
        // require(token0Address != token1Address,"Both tokens can't be same");
        pairId++;
        pairDetails[pairId].token0= token0Address;
        pairDetails[pairId].token1= token1Address;
        pairDetails[pairId].token0Name= _token0Name;
        pairDetails[pairId].token1Name= _token1Name;
        pairDetails[pairId].Timestamp= block.timestamp;
        pairDetails[pairId].reserve0= token0Address.balanceOf(address(this));
        pairDetails[pairId].reserve1= token1Address.balanceOf(address(this));
        liquidityProviders[msg.sender][pairId].token0Amount= _token0totalSupply ;
        liquidityProviders[msg.sender][pairId].token1Amount= _token1totalSupply ;
        liquidityProviders[msg.sender][pairId].liquidityProviderAddress= msg.sender ;
    }

    function depositLiquidity(uint _token0Amount, uint _token1Amount, uint _pairId)public {
        token0Address.mint(msg.sender,_token0Amount);
        token1Address.mint(msg.sender,_token1Amount);
        require(_token0Amount > 0 && _token1Amount > 0, "Deposited amounts must be greater than zero");
        require(token0Address.balanceOf(msg.sender)>0,"Balance should be greater than 0");
        token0Address.approve(msg.sender,address(this), _token0Amount);
        token0Address.transferFrom(msg.sender, address(this), _token0Amount);
        liquidityProviders[msg.sender][_pairId].token0Amount= _token0Amount ;
        pairDetails[pairId].reserve0 += _token0Amount;
        token1Address.approve(msg.sender,address(this), _token1Amount);
        token1Address.transferFrom(msg.sender, address(this), _token1Amount);
        liquidityProviders[msg.sender][_pairId].token1Amount= _token1Amount ;
        pairDetails[pairId].reserve1 += _token1Amount;
        liquidityProviders[msg.sender][_pairId].liquidityProviderAddress = msg.sender;
    }

    function withdrawLiquidity(uint _pairId)public{
        require(liquidityProviders[msg.sender][_pairId].token0Amount & liquidityProviders[msg.sender][_pairId].token1Amount > 0,"You have't provided the liquidity");
        token0Address.transferFrom(address(this),msg.sender ,liquidityProviders[msg.sender][_pairId].token0Amount);
        token1Address.transferFrom(address(this),msg.sender, liquidityProviders[msg.sender][_pairId].token1Amount);
        pairDetails[pairId].reserve0 -=liquidityProviders[msg.sender][_pairId].token0Amount;
        pairDetails[pairId].reserve1 -=liquidityProviders[msg.sender][_pairId].token1Amount;
    }
}




// Method to enter the struct value in one tym
// pairDetails[pairId]=pairdata({
// });