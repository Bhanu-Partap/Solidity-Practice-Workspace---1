// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard {

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    using SafeMath for uint256;
    uint256 public constant Reward_Rate = 1e18;  
    uint256 private  totalStakedTokens;
    uint256 public  rewardperTokenStored;
    uint256 public lastUpdateTime;

    mapping(address=>uint) public stakedBalance;
    mapping(address=>uint) public rewards;
    mapping(address=>uint) public userRewardPerTokenPaid;

    event Staked(address indexed user, uint indexed  amount);
    event Withdrawn(address indexed user, uint indexed  amount);
    event RewardsClaimed(address indexed user, uint indexed  amount);

    constructor(address _stakingToken, address _rewardToken){
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address user){
        rewardperTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        rewards[user]= rewardsEarned(user);
        userRewardPerTokenPaid[user] = rewardperTokenStored;
        _;

    }

    function rewardPerToken()public view  returns(uint) {
        if(totalStakedTokens == 0){
            return rewardperTokenStored;
        }
        uint totalTime= block.timestamp.sub(lastUpdateTime);
        uint totalReward = Reward_Rate.mul(totalTime);
        return rewardperTokenStored.add(totalReward.mul(1e18)).div(totalStakedTokens);
    }

    function rewardsEarned(address user) public view returns(uint){
        return (stakedBalance[user].mul(rewardPerToken().sub(userRewardPerTokenPaid[user])));
    }

    function stake(uint amount) external nonReentrant updateReward(msg.sender){
        require(amount > 0,"Amount must be greater than 0");
        totalStakedTokens+=amount;
        stakedBalance[msg.sender]+=amount;
        emit Staked(msg.sender, amount);
        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success,"Transfer Failed");
    }

    function withdraw(uint amount) external nonReentrant updateReward(msg.sender){
        require(amount > 0,"Amount must be greater than 0");
        require(stakedBalance[msg.sender]>=amount,"Stakend amount is not enough");
        totalStakedTokens-=amount;
        stakedBalance[msg.sender]-=amount;
        emit Withdrawn(msg.sender, amount);
        bool success = stakingToken.transfer(msg.sender,amount); 
        require(success,"Transfer Failed");
    }

    function claimReward() external nonReentrant updateReward(msg.sender){
        uint reward = rewards[msg.sender];
        require(reward > 0, " Not having any rewards");
        rewards[msg.sender] = 0;
        emit RewardsClaimed(msg.sender, reward);
        bool success = rewardToken.transfer(msg.sender,reward); 
        require(success,"Transfer Failed");
    }
}