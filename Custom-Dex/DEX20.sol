// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {

    string private name;
    string private symbol;
    uint256 private totalSupply = 1000000 * 10**18;

    constructor(string memory _name, string memory _symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); 
        name=_name;
        symbol=_symbol;

    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
