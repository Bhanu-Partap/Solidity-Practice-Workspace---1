// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract MFGLocker  {

    IERC20 oldMfgContract;
    IERC20 newMfgContract;

    constructor(address _oldMfgContract ,address _newMfgContract){
        oldMfgContract=IERC20(_oldMfgContract);
        newMfgContract = IERC20(_newMfgContract);

    }

    function lockAndMint(uint amount) public{
        
        oldMfgContract.transferFrom(msg.sender,address(this),amount);
        newMfgContract.transfer(msg.sender,amount);

    }
}