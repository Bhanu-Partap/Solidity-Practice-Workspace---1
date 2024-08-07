// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Lottery {
    address public owner;
    address[] public participants;
    uint256 public lotteryCount;

    mapping(uint256 => address ) public lotterySlotWinner;

    constructor() {
        owner = msg.sender;
    }

    modifier restricted() {
        require(msg.sender == owner, "Only Owner can Pick winner");
        _;
    }

    function enter() public payable {
        require(msg.value > 0.1 ether, "Minimum Ether not met");
        participants.push(msg.sender);
    }

    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, participants)));
    }

    function pickWinner() public restricted{
        uint index = random() % participants.length;
        payable(participants[index]).transfer(address(this).balance);
        lotteryCount++;
        lotterySlotWinner[lotteryCount] = participants[index];
        delete participants;
    }

    function getPotBalance()public view returns(uint256){
        // return address(this).balance /10**18;        IN ETH
        return address(this).balance;

    }

}
