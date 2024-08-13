// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract erc20token is IERC20, ERC20 {
    constructor() ERC20("wrapped ETH","ETH") {}

    function PublicMint() public payable {
        _mint(msg.sender, msg.value);
    }
}