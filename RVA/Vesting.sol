// 3 month lock period and 12 months of token release time

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Token.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";


contract TokenVesting is Ownable {
    using SafeMath for uint256;

    erc20token public token;
    address public icoContract; 

    struct VestingSchedule {
        uint256 totalTokens;      // Total tokens allocated to the investor
        uint256 claimedTokens;    // Tokens already claimed
        uint256 lockUpEndTime;    // End time of lock-up period
        uint256 cliffEndTime;     // End time of cliff period
        uint256 vestingEndTime;   // End time of vesting period
    }

    // mapping(address => VestingSchedule) public vestingSchedules;
    mapping(uint256 => mapping(address => VestingSchedule)) public vestingSchedules; // saleId => (investor => VestingSchedule)


    event VestingAllocated(address beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration);
    event TokensClaimed(address beneficiary, uint256 amount);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = erc20token(_tokenAddress);
    }

    // Allocate vesting to a user
    function registerVesting(
    uint256 saleId,
    address investor,
    uint256 amount,
    uint256 startTime,
    uint256 lockUpPeriod,
    uint256 cliffPeriod,
    uint256 vestingPeriod
    ) external {
    require(msg.sender == icoContract, "ICO contract can register vesting");
    vestingSchedules[saleId][investor] = VestingSchedule({
        totalTokens: amount,
        claimedTokens: 0,
        lockUpEndTime: startTime + lockUpPeriod,
        cliffEndTime: startTime + lockUpPeriod + cliffPeriod,
        vestingEndTime: startTime + lockUpPeriod + cliffPeriod + vestingPeriod
    });
}

    function claimTokens(uint256 saleId) external {
        VestingSchedule storage schedule = vestingSchedules[saleId][msg.sender];
        require(schedule.totalTokens > 0, "No vesting schedule found");

        uint256 currentTime = block.timestamp;
        require(currentTime >= schedule.lockUpEndTime, "Lock-up period not ended");
    
        // Calculating vested tokens
        uint256 vestedTokens = 0;
        if (currentTime >= schedule.vestingEndTime) {
            vestedTokens = schedule.totalTokens;
        } else {
            uint256 elapsedTime = currentTime - schedule.cliffEndTime;
            uint256 vestingDuration = schedule.vestingEndTime - schedule.cliffEndTime;
            vestedTokens = (schedule.totalTokens * elapsedTime) / vestingDuration;
        }

        uint256 claimableTokens = vestedTokens - schedule.claimedTokens;
        require(claimableTokens > 0, "No tokens available for claim");

        schedule.claimedTokens += claimableTokens;
        _transferTokens(msg.sender, claimableTokens);
} 



}
