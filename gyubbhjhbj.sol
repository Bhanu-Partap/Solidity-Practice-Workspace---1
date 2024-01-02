pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingContract {
    struct Staking {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool isFixed;
        bool isStaked;
    }

    mapping(address => Staking) public stakings;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public claimedRewards;
    mapping(address => uint256) public unclaimedRewards;

    IERC20 public token;
    uint256 public penaltyPercentage;
    uint256 public fixedInterestRate;
    uint256 public unfixedInterestRate;

    event Staked(address indexed user, uint256 amount, bool isFixed);
    event Unstaked(address indexed user, uint256 amount, bool isFixed);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(
        address _tokenAddress,
        uint256 _penaltyPercentage,
        uint256 _fixedInterestRate,
        uint256 _unfixedInterestRate
    ) {
        token = IERC20(_tokenAddress);
        penaltyPercentage = _penaltyPercentage;
        fixedInterestRate = _fixedInterestRate;
        unfixedInterestRate = _unfixedInterestRate;
    }

    function stake(uint256 _amount, bool _isFixed, uint256 _duration) external {
        require(!stakings[msg.sender].isStaked, "Already staked");

        if (_isFixed) {
            require(_duration > 0, "Invalid duration");
            stakings[msg.sender] = Staking(_amount, block.timestamp, _duration, true, true);
        } else {
            stakings[msg.sender] = Staking(_amount, 0, 0, false, true);
        }

        balances[msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount, _isFixed);
    }

    function unstake() external {
        require(stakings[msg.sender].isStaked, "Not staked");
        Staking memory staking = stakings[msg.sender];
        uint256 stakedAmount = staking.amount;

        if (staking.isFixed) {
            require(block.timestamp >= staking.startTime + staking.duration, "Fixed staking not expired");
            uint256 penalty = (staking.amount * penaltyPercentage) / 100;
            stakedAmount -= penalty;
        }

        delete stakings[msg.sender];
        balances[msg.sender] -= stakedAmount;
        token.transfer(msg.sender, stakedAmount);

        emit Unstaked(msg.sender, stakedAmount, staking.isFixed);
    }

    function claimReward() external {
        require(stakings[msg.sender].isStaked, "Not staked");

        uint256 reward;
        Staking memory staking = stakings[msg.sender];
        if (staking.isFixed) {
            reward = calculateReward(staking.amount, staking.startTime, staking.duration, fixedInterestRate);
        } else {
            reward = calculateReward(staking.amount, staking.startTime, block.timestamp - staking.startTime, unfixedInterestRate);
        }

        rewards[msg.sender] += reward;
        unclaimedRewards[msg.sender] += reward;

        emit RewardClaimed(msg.sender, reward);
    }

    function calculateReward(uint256 _amount, uint256 _startTime, uint256 _duration, uint256 _interestRate) internal pure returns (uint256) {
        uint256 reward = (_amount * _interestRate * _duration) / (100 * 365 days);
        return reward;
    }

    function getClaimableRewards() external {
        uint256 unclaimedReward = unclaimedRewards[msg.sender];
        unclaimedRewards[msg.sender] = 0;
        claimedRewards[msg.sender] += unclaimedReward;
        token.transfer(msg.sender, unclaimedReward);
    }
}
