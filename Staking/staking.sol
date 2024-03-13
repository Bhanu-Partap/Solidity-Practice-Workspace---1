// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard {

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public constant Reward_Rate = 10;  
    uint256 private  totalStakeTokens;
    uint256 public  rewardperTokenStored;
    uint256 public lastUpdateTime;

    mapping(address=>uint) public stakedBalance;
    mapping(address=>uint) public rewards;
    mapping(address=>uint) public userRewardPerToken;

    event Staked(address indexed user, uint indexed  amount);
    event Withdraw(address indexed user, uint indexed  amount);
    event RewardsClaimed(address indexed user, uint indexed  amount);

    constructor(address _stakingToken, address _rewardToken){
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

}