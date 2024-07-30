// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "hardhat/console.sol";

import "@openzeppelin/contracts@4.9.6/token/ERC20/ERC20.sol";

contract GEMERC20 is ERC20 {

    address public vaultAddress;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function Mint(address recipient, uint256 Amount) public {
        require(msg.sender == vaultAddress, "forbidden");
        _mint(recipient, Amount);
    }

    function Burn(address recipient, uint256 Amount) public {
        require(msg.sender == vaultAddress, "forbidden");
        _burn(recipient, Amount);
    }

    function setVault(address _vaultAddress) public {
        require(vaultAddress == address(0), "already initialised");
        vaultAddress = _vaultAddress;
    }
}
