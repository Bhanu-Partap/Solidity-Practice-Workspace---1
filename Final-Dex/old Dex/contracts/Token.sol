// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract erc20token is IERC20, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function PublicMint(address recipient, uint256 Amount) public {
        _mint(recipient, Amount);
    }

    function decimals() public pure override returns (uint8) {
        return 13;
    }

}


//  [
// 		"0x08aAD3F6D3FbE57A4f25F17209502491Cd141308",5
// 		"0x13Ef33e7703c9BFaA55e17F8dB711D1f10204E01",13
// 		"0x08910b3167137C280a55F6271daFcF4B398369C0"
// ]