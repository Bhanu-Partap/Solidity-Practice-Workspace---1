// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Erc-20.sol";
import "hardhat/console.sol";

contract LpTokens{

    erc20 token0;
    erc20 token1;
    erc20 lptokens;


    constructor(address _token0, address _token1) {
        token0 = erc20(_token0);
        token1 = erc20(_token1);
    }

    function mintingLpTokens(uint _amount0, uint _amount1) external returns(uint){
        
        // // require(_amount0 > 0 && _amount1 > 0, "Amounts must be greater than zero");
        // // uint256 totalSupply = lptokens.totalSupply(); 
        // // console.log(totalSupply);
        // token0.approve(msg.sender, address(this), _amount0);
        // token0.transferFrom(msg.sender, address(this), _amount0);
        // // require(token0.transferFrom(msg.sender, address(this), _amount0), "TokenA transfer failed");
        // token1.approve(msg.sender, address(this), _amount1);
        // token1.transferFrom(msg.sender, address(this), _amount1);
        // // require(token1.transferFrom(msg.sender, address(this), _amount1), "TokenB transfer failed");
        // lptokens.mint(msg.sender,_amount0 + _amount1);
        // // return totalSupply;
    }

    function burningLpTokens() external 
}

