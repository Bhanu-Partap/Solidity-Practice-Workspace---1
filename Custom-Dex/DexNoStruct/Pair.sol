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
    
    constructor(string memory _name, string memory _symbol){
        token0address = new erc20token(_name,_symbol);
    }

    function createPair(address token0address, address token1address)  public returns(uint256){
                    
    }

}