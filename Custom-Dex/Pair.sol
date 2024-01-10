// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Erc-20.sol";

contract Pair {

uint fee;

struct pairdata{
    address token0;
    address token1;
    uint reserve0;
    uint reserve1;
    uint blockTimestampLast;    
    uint id;
}
mapping(uint=>pairdata) public tokenDetails;

}
