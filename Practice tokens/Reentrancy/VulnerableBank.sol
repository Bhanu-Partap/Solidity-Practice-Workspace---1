// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract VulnerableBank {
    mapping(address => uint256) public balances;

    // Function to deposit Ether into the contract
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    // Function to withdraw Ether from the contract
    function withdraw() public {
        // require(balances[msg.sender] >= amount, "Insufficient balance");
        uint bal = balances[msg.sender];
        require(bal>0,"Not sufficient Balance");

        // Send Ether to the caller
        (bool success, ) = msg.sender.call{value: bal}("");
        require(success, "Transfer failed");

        // Update the state after sending Ether (vulnerability)
        balances[msg.sender] -= 1 ether;
    }

    function transfer(address _to,uint256 _amount)public {
        balances[msg.sender] -= _amount;
        balances[_to]+=_amount;
    }
}


