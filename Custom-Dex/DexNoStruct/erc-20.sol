// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract Eth is ERC20, ERC20Burnable, Ownable {
//     constructor(address initialOwner) ERC20("Eth", "ETH") Ownable(initialOwner) {
//         _mint(msg.sender, 100000 * 10 ** 18);

//     }

//     function mint(address to, uint256 amount) public onlyOwner {
//         _mint(to, amount);
//     }
// }


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