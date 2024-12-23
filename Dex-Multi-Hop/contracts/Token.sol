// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract erc20token is IERC20, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function PublicMint(address recipient, uint256 Amount) public {
        _mint(recipient, Amount);
    }

    function decimals() public pure override returns (uint8) {
        return 4;
    }

}


//  [
// 		"0x4d559df9e82C2E95Fc6104D717ae8e58994C2077",
// 		"0xDc4aA48D81B4e277B47722be5468BeB51A72d4DD",
// 		"0x1939938Bf9ca6ED967006A0e84220b2BAEd725E7"
// ]


