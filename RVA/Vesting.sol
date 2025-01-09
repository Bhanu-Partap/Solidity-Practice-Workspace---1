// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./UpgradableToken.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;
    // using Address for address;

    ERC20Token public icoToken;
    address public icoContract;

    struct VestingSchedule {
        uint256 saleId;
        uint256 totalTokens;   
        uint256 claimedTokens; 
        uint256 lockedTokens;  
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
        uint256 _claimedTokens,
        uint256 _lockedTokens,
        uint256 _startTime,
        uint256 _lockUpPeriod,
        uint256 _vestingPeriod,
        uint256 _vestingInterval
    ) external {
        require(msg.sender == icoContract, "Only ICO contract can register vesting");
        require(_investor != address(0), "Null Investor address");
        require(_tokenAmount > 0, "Invalid Amount");
        require(_lockUpPeriod > 0, "Invalid Lockup period");
        require(_vestingPeriod > 0, "Invalid Vesting period");
        require(_vestingInterval > 0, "Invalid Vesting interval");
        vestingSchedules[_saleId][_investor] = VestingSchedule({
            saleId : _saleId,
            totalTokens: _tokenAmount,
            claimedTokens: _claimedTokens,
            lockedTokens : _lockedTokens,
            startTime: _startTime,
            lockUpEndTime: _startTime + _lockUpPeriod,
            vestingEndTime: _startTime + _lockUpPeriod + _vestingPeriod,
            vestingInterval: _startTime + _lockUpPeriod +_vestingInterval
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
        require(_icoContract != address(0), "Null Address");
        // require(isContract(_icoAddress), "Address is not a contract");
        icoContract = _icoContract;
    }
}
