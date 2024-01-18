// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.1/contracts/token/ERC20/ERC20.sol";

contract erc20token is ERC20{
    constructor(string memory name, string memory symbol) ERC20(name,symbol){
        _mint(msg.sender, 1000000 * 10**18); 
        
    }

    function PublicMint(address recipient , uint Amount) public{
        _mint(recipient,Amount);
    }

     function approve(address _owner,address spender, uint256 amount) public virtual returns (bool) {
        address owner = _owner;
        _approve(owner, spender, amount);
        return true;
    }

}