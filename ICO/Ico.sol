// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "./VestingContract.sol";
// import "./Erc20.sol";

// contract ICO is Ownable {
//     using SafeMath for uint256;

//     erc20token public token;
//     uint256 public startTime;
//     uint256 public endTime;
//     uint256 public tier1Price;
//     uint256 public tier2Price;
//     mapping(address => bool) public whitelisted;
//     mapping(address => uint256) public contributions;
//     address[] public contributors;

//     enum VestingState { NotStarted, Active, Completed }
//     VestingState public vestingState;
//     uint256 public vestingStart;
//     uint256 public vestingDuration; // In seconds

//     event TokenPurchased(address indexed buyer, uint256 amount, uint256 cost);
//     event Whitelisted(address indexed account);
//     event Blacklisted(address indexed account);

//     constructor(erc20token _token, uint256 _startTime, uint256 _endTime, uint256 _tier1Price, uint256 _tier2Price) Ownable(msg.sender){
//         require(_startTime < _endTime, "Invalid time range");
//         token = _token;
//         startTime = _startTime;
//         endTime = _endTime;
//         tier1Price = _tier1Price;
//         tier2Price = _tier2Price;
//     }

//     modifier onlyWhileOpen() {
//         require(block.timestamp >= startTime && block.timestamp <= endTime, "ICO not active");
//         _;
//     }

//     modifier isWhitelisted() {
//         require(whitelisted[msg.sender], "Not whitelisted");
//         _;
//     }

//     function buyTokens(uint256 _amount) external payable onlyWhileOpen isWhitelisted {
//         uint256 cost;
//         if (block.timestamp < startTime + 1 weeks) {
//             cost = _amount.mul(tier1Price);
//         } else {
//             cost = _amount.mul(tier2Price);
//         }
//         require(msg.value >= cost, "Insufficient ETH sent");
//         contributions[msg.sender] = contributions[msg.sender].add(msg.value);
//         token.transfer(msg.sender, _amount);
//         emit TokenPurchased(msg.sender, _amount, cost);
//     }

//     function whitelistUser(address _user) external onlyOwner {
//         whitelisted[_user] = true;
//         emit Whitelisted(_user);
//     }

//     function blacklistUser(address _user) external onlyOwner {
//         whitelisted[_user] = false;
//         emit Blacklisted(_user);
//     }

//     function startVesting(uint256 _duration) external onlyOwner {
//         vestingStart = block.timestamp;
//         vestingDuration = _duration;
//         vestingState = VestingState.Active;
//     }

//     function releaseTokens() external {
//         require(vestingState == VestingState.Active, "Vesting not active");
//         require(block.timestamp >= vestingStart.add(vestingDuration), "Vesting period not completed");
//         vestingState = VestingState.Completed;
//         // Logic to release tokens to beneficiaries goes here
//     }

//     function refund() external {
//         require(block.timestamp > endTime, "ICO still active");
//         uint256 contribution = contributions[msg.sender];
//         require(contribution > 0, "No contribution to refund");
//         contributions[msg.sender] = 0;
//         payable(msg.sender).transfer(contribution);
//     }
// }


pragma solidity ^0.8.26;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VestingContract.sol"; // Import the vesting contract
import "./Erc20.sol";

contract ICO is Ownable {
    using SafeMath for uint256;

    IERC20 public token;                 // ERC20 token for sale
    TokenVesting public vestingContract; // Reference to the vesting contract

    uint256 public phaseOneRate;         // Token price in Phase 1
    uint256 public phaseTwoRate;         // Token price in Phase 2
    uint256 public phaseThreeRate;       // Token price in Phase 3
    uint256 public phaseOneEnd;
    uint256 public phaseTwoEnd;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public totalRaised;
    bool public isFinalized;

    event TokensPurchased(address indexed buyer, uint256 amount);

    modifier onlyDuringICO() {
        require(block.timestamp <= phaseTwoEnd, "ICO has ended");
        _;
    }

    modifier hasEnded() {
        require(block.timestamp > phaseTwoEnd, "ICO has not ended yet");
        _;
    }

    constructor(
        address _tokenAddress,
        address _vestingContractAddress,
        uint256 _phaseOneRate,
        uint256 _phaseTwoRate,
        uint256 _phaseThreeRate,
        uint256 _phaseOneDuration,
        uint256 _phaseTwoDuration,
        uint256 _softCap,
        uint256 _hardCap
    ) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        vestingContract = TokenVesting(_vestingContractAddress);
        phaseOneRate = _phaseOneRate;
        phaseTwoRate = _phaseTwoRate;
        phaseThreeRate = _phaseThreeRate;
        phaseOneEnd = block.timestamp + _phaseOneDuration;
        phaseTwoEnd = phaseOneEnd + _phaseTwoDuration;
        softCap = _softCap;
        hardCap = _hardCap;
    }

    function getCurrentRate() public view returns (uint256) {
        if (block.timestamp <= phaseOneEnd) {
            return phaseOneRate;
        } else if (block.timestamp <= phaseTwoEnd) {
            return phaseTwoRate;
        } else {
            return phaseThreeRate;
        }
    }

    function buyTokens() external payable onlyDuringICO {
        uint256 rate = getCurrentRate();
        uint256 tokenAmount = msg.value.mul(rate);
        require(totalRaised.add(msg.value) <= hardCap, "Exceeds hard cap");
        // Update total raised funds
        totalRaised = totalRaised.add(msg.value);
        // Allocate vesting if the user is a first-time buyer
        vestingContract.allocateVesting(msg.sender, tokenAmount, 365 days); // 1 year vesting

        emit TokensPurchased(msg.sender, tokenAmount);
    }

    function finalizeICO() external onlyOwner hasEnded {
        require(!isFinalized, "ICO already finalized");
        
        if (totalRaised >= softCap) {
            payable(owner()).transfer(address(this).balance); // Transfer funds to owner
        } else {
            // Handle refund logic if needed
            isFinalized = true;
        }
    }

}

