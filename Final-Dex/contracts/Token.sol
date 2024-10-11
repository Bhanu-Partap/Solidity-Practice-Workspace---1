// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract erc20token is IERC20, ERC20,ERC20Permit {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    function PublicMint(address recipient, uint256 Amount) public {
        _mint(recipient, Amount);
    }

    function decimals() public pure override returns (uint8) {
        return 13;
    }

}
