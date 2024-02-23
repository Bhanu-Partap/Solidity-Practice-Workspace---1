// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract erc20token is IERC20, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function PublicMint(address recipient, uint256 Amount) public {
        _mint(recipient, Amount);
    }

    function approve(
        address _owner,
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        address owner = _owner;
        _approve(owner, spender, amount);
        return true;
    }

     function decimals() public pure override  returns (uint8) {
        return 4;
    }

}
