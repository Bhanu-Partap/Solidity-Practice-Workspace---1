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


    event VestingAllocated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration);
    event TokensClaimed(address indexed beneficiary, uint256 amount);

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



// lock up vesting and cliff period 

// pragma solidity ^0.8.0;

// contract AllInOneVesting {
//     address public owner;
//     address public beneficiary;

//     uint256 public startTime;        // When vesting starts
//     uint256 public cliffDuration;    // Duration of the cliff period
//     uint256 public vestingDuration;  // Total vesting duration
//     uint256 public lockUpDuration;   // Lock-up period after vesting

//     uint256 public totalTokens;      // Total tokens allocated for vesting
//     uint256 public tokensClaimed;    // Tokens already claimed

//     event TokensClaimed(address indexed beneficiary, uint256 amount, uint256 timestamp);
//     event VestingCompleted(address indexed beneficiary, uint256 totalTokens, uint256 timestamp);

//     constructor(
//         address _beneficiary,
//         uint256 _startTime,
//         uint256 _cliffDuration,
//         uint256 _vestingDuration,
//         uint256 _lockUpDuration,
//         uint256 _totalTokens
//     ) {
//         require(_beneficiary != address(0), "Invalid beneficiary address");
//         require(_cliffDuration <= _vestingDuration, "Cliff exceeds vesting duration");

//         owner = msg.sender;
//         beneficiary = _beneficiary;
//         startTime = _startTime;
//         cliffDuration = _cliffDuration;
//         vestingDuration = _vestingDuration;
//         lockUpDuration = _lockUpDuration;
//         totalTokens = _totalTokens;
//     }

//     function claimTokens() external {
//         require(msg.sender == beneficiary, "Only beneficiary can claim tokens");
//         require(block.timestamp >= startTime + cliffDuration, "Cliff period not reached");

//         uint256 elapsedTime = block.timestamp - startTime;
//         uint256 vestedAmount;

//         if (elapsedTime >= vestingDuration) {
//             // All tokens are vested after the vesting period
//             vestedAmount = totalTokens;
//         } else {
//             // Gradual vesting calculation
//             vestedAmount = (totalTokens * elapsedTime) / vestingDuration;
//         }

//         uint256 claimable = vestedAmount - tokensClaimed;

//         require(claimable > 0, "No tokens available to claim");
//         tokensClaimed += claimable;

//         // Ensure lock-up restrictions
//         if (block.timestamp < startTime + vestingDuration + lockUpDuration) {
//             revert("Tokens are locked and cannot be transferred yet");
//         }

//         // Simulate token transfer (replace with actual ERC20 transfer logic)
//         // token.transfer(beneficiary, claimable);

//         emit TokensClaimed(beneficiary, claimable, block.timestamp);

//         // Emit event when fully vested
//         if (tokensClaimed == totalTokens) {
//             emit VestingCompleted(beneficiary, totalTokens, block.timestamp);
//         }
//     }
// }
