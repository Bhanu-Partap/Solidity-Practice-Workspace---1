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
}