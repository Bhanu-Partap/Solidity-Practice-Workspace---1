// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract erc20token is IERC20, ERC20 {

    uint256 private _totalSupply = 1000000 * 10 ** 18; // 1 million tokens with 18 decimals

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
         _mint(msg.sender, _totalSupply); // Mint the total supply to the owner
    }
    
    function decimals() public pure override returns (uint8) {
        return 18;
    }

}