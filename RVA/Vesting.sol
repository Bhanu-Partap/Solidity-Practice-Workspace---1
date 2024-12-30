// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./UpgradableToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;

    ERC20Token public icoToken;
    address public icoContract;

    struct VestingSchedule {
        uint256 saleId;
        uint256 totalTokens;   
        uint256 claimedTokens;   
        uint256 startTime; 
        uint256 lockUpEndTime; 
        uint256 vestingEndTime;  
        uint256 vestingInterval; 
    }

    // Mapping: saleId => (investor => VestingSchedule)
    mapping(uint256 => mapping(address => VestingSchedule)) public vestingSchedules;

    event VestingAllocated(address indexed beneficiary, uint256 totalAmount, uint256 lockUpEndTime, uint256 vestingEndTime, uint256 vestingInterval);
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    constructor(address _tokenAddress, address _icoAddress) Ownable(msg.sender) {
        icoToken = ERC20Token(_tokenAddress);
        icoContract = _icoAddress;
    }

    // Allocate vesting to a user
    function registerVesting(
        address _investor,
        uint256 _saleId,
        uint256 _tokenAmount,
        uint256 _startTime,
        uint256 _lockUpPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingInterval
    ) external {
        require(msg.sender == icoContract, "Only ICO contract can register vesting");
        vestingSchedules[_saleId][_investor] = VestingSchedule({
            saleId : _saleId,
            totalTokens: _tokenAmount,
            claimedTokens: 0,
            startTime: _startTime,
            lockUpEndTime: _startTime + _lockUpPeriod,
            vestingEndTime: _startTime + _lockUpPeriod + _vestingPeriod,
            vestingInterval: _vestingInterval
        });
        emit VestingAllocated(_investor, _tokenAmount, _startTime + _lockUpPeriod, _startTime + _lockUpPeriod + _vestingPeriod, _vestingInterval);
    }


    // Claim vested tokens
    function claimTokens(uint256 saleId) external {
        VestingSchedule storage schedule = vestingSchedules[saleId][msg.sender];
        require(schedule.totalTokens > 0, "No vesting schedule found");

        uint256 currentTime = block.timestamp;
        require(currentTime >= schedule.lockUpEndTime, "Lock-up period not ended");

        // Calculate vested tokens
        uint256 vestedTokens;
        if (currentTime >= schedule.vestingEndTime) {
            vestedTokens = schedule.totalTokens;
        } else {
            uint256 elapsedTime = currentTime - schedule.lockUpEndTime;
            uint256 vestingDuration = schedule.vestingEndTime - schedule.lockUpEndTime;
            vestedTokens = (schedule.totalTokens * elapsedTime) / vestingDuration;
        }

        uint256 claimableTokens = vestedTokens - schedule.claimedTokens;
        require(claimableTokens > 0, "No tokens available for claim");

        schedule.claimedTokens += claimableTokens;
        icoToken.transfer(msg.sender, claimableTokens);

        emit TokensClaimed(msg.sender, claimableTokens);
    }

    // Set the ICO contract address
    function setIcoContract(address _icoContract) external onlyOwner {
        icoContract = _icoContract;
    }
}


// function createVestingSchedule(
//     address beneficiary,
//     uint256 amount,
//     uint256 startTime,
//     uint256 duration
// ) external onlyICO {
//     require(beneficiary != address(0), "Invalid beneficiary");
//     require(amount > 0, "Amount must be greater than zero");

//     // Store the vesting schedule
//     vestingSchedules[beneficiary] = VestingSchedule({
//         amount: amount,
//         startTime: startTime,
//         duration: duration,
//         released: 0
//     });
// }

// function claim() external {
//     VestingSchedule storage schedule = vestingSchedules[msg.sender];
//     require(schedule.amount > 0, "No vesting schedule found");
    
//     uint256 vestedAmount = _computeVestedAmount(schedule);
//     uint256 claimableAmount = vestedAmount - schedule.released;

//     require(claimableAmount > 0, "No tokens to claim");

//     schedule.released += claimableAmount;
//     require(token.transfer(msg.sender, claimableAmount), "Token transfer failed");
// }



// function _computeVestedAmount(VestingSchedule memory schedule) private view returns (uint256) {
//     if (block.timestamp < schedule.startTime) {
//         return 0;
//     }
//     uint256 elapsedTime = block.timestamp - schedule.startTime;
//     uint256 vestedAmount = (schedule.amount * elapsedTime) / schedule.duration;

//     return elapsedTime >= schedule.duration ? schedule.amount : vestedAmount;
// }
