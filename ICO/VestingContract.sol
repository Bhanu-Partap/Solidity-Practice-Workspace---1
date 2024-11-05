// 3 month lock period and 12 months of token release time

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Erc20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";


contract TokenVesting is Ownable {
    using SafeMath for uint256;

    erc20token public token;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountClaimed;
        uint256 startTime;
        uint256 duration; // Vesting period in seconds
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    event VestingAllocated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration);
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = erc20token(_tokenAddress);
    }

    // Allocate vesting to a user
    function allocateVesting(address beneficiary, uint256 tokenAmount, uint256 duration) external {
        console.log("Entered in allocating vesting function");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting already exists for this address");
        console.log("condition checked in allocating vesting function");
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: tokenAmount,
            amountClaimed: 0,
            startTime: block.timestamp,
            duration: duration
        });
        console.log("vesting allocated");
        emit VestingAllocated(beneficiary, tokenAmount, block.timestamp, duration);
    }

    // Claim available vested tokens
    function claimVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule for this address");
        
        uint256 timeElapsed = block.timestamp.sub(schedule.startTime);
        uint256 totalUnlocked = schedule.totalAmount.mul(timeElapsed).div(schedule.duration);
        uint256 claimable = totalUnlocked.sub(schedule.amountClaimed);

        require(claimable > 0, "No tokens to claim");

        schedule.amountClaimed = schedule.amountClaimed.add(claimable);
        token.transfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    // Withdraw unclaimed tokens if vesting is canceled or modified
    function withdrawUnclaimedTokens(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        uint256 remainingAmount = schedule.totalAmount.sub(schedule.amountClaimed);
        delete vestingSchedules[beneficiary];
        
        token.transfer(owner(), remainingAmount);
    }
}
