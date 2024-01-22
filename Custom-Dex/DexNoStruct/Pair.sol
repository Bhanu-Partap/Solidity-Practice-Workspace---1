// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import  "./erc-20.sol";

contract Pair{

    erc20token token0address;
    erc20token token1address;
    erc20token lptokens;

    uint256 private reserve0;
    uint256 private reserve1;
    uint256 private timestamp;
    uint256 private token0Amount;
    uint256 private token1Amount;
    uint public constant MINIMUM_LIQUIDITY = 10**3;


    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    constructor(string memory _name, string memory _symbol){
        token0address = new erc20token(_name,_symbol);
        token1address = new erc20token(_name,_symbol);
    }


    function getErcAddress()public view returns(erc20token ){
        return token0address;
    }

    function createPair(address _token0Address, address _token1Address, uint256 _token0Amount, uint256 _token1Amount )  public returns(uint256){

    }


    function addLiquidity(address _token0Address, address token1Address, uint256 _token0Amount, uint256 _token1Amount )  public returns(uint256){

    }

    
    function removeLiquidity(address _token0Address, address token1Address)  public returns(uint256){

    }


    function swap(address from, address to , uint256 amount)  public returns(uint256){

    }

}