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



//=================VESTING PERIOD ONE=======================//

// pragma solidity ^0.8.26;

// // import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "./VestingContract.sol"; // Import the vesting contract
// import "./Erc20.sol";
// import "hardhat/console.sol";

// contract ICO is Ownable {
//     using SafeMath for uint256;

//     IERC20 public token;                 // ERC20 token for sale
//     TokenVesting public vestingContract; // Reference to the vesting contract

//     uint256 public tierOneRate;         // Token price in tier 1
//     uint256 public tierTwoRate;         // Token price in tier 2
//     uint256 public tierThreeRate;       // Token price in tier 3
//     uint256 public tierOneEnd;
//     uint256 public tierTwoEnd;
//     uint256 public softCap;
//     uint256 public hardCap;
//     uint256 public totalRaised;
//     bool public isFinalized;

//     event TokensPurchased(address indexed buyer, uint256 amount);

//     modifier onlyDuringICO() {
//         require(block.timestamp <= tierTwoEnd, "ICO has ended");
//         _;
//     }

//     modifier hasEnded() {
//         require(block.timestamp > tierTwoEnd, "ICO has not ended yet");
//         _;
//     }

//     constructor(
//         address _tokenAddress,
//         address _vestingContractAddress,
//         uint256 _tierOneRate,
//         uint256 _tierTwoRate,
//         uint256 _tierThreeRate,
//         uint256 _tierOneDuration,
//         uint256 _tierTwoDuration,
//         uint256 _softCap,
//         uint256 _hardCap
//     ) Ownable(msg.sender) {
//         token = IERC20(_tokenAddress);
//         vestingContract = TokenVesting(_vestingContractAddress);
//         tierOneRate = _tierOneRate;
//         tierTwoRate = _tierTwoRate;
//         tierThreeRate = _tierThreeRate;
//         tierOneEnd = block.timestamp + _tierOneDuration;
//         tierTwoEnd = tierOneEnd + _tierTwoDuration;
//         softCap = _softCap;
//         hardCap = _hardCap;
//     }

//     function getCurrentRate() public view returns (uint256) {
//         if (block.timestamp <= tierOneEnd) {
//             return tierOneRate;
//         } else if (block.timestamp <= tierTwoEnd) {
//             return tierTwoRate;
//         } else {
//             return tierThreeRate;
//         }
//     }

//     function buyTokens() external payable onlyDuringICO {
//         uint256 rate = getCurrentRate();
//         console.log("rate",rate);
//         uint256 tokenAmount = msg.value.mul(rate);
//         console.log("tokenAmount",tokenAmount);
//         require(totalRaised.add(msg.value) <= hardCap, "Exceeds hard cap");
//         // Update total raised funds
//         totalRaised = totalRaised.add(msg.value);
//         console.log("totalRaised",totalRaised);

//         // Allocate vesting if the user is a first-time buyer
//         vestingContract.allocateVesting(msg.sender, tokenAmount, 183 days); // 1 year vesting
        
//         emit TokensPurchased(msg.sender, tokenAmount);
//     }

//     function finalizeICO() external onlyOwner hasEnded {
//         require(!isFinalized, "ICO already finalized");
        
//         if (totalRaised >= softCap) {
//             payable(owner()).transfer(address(this).balance); // Transfer funds to owner
//         } else {
//             // Handle refund logic if needed
//             isFinalized = true;
//         }
//     }

// }

//======================ONLY PUBLIC SALE======================//

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DynamicICO is Ownable {

    //struct
    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 tokensSold;
        bool isFinalized;
    }

    //state variable
    IERC20 public token;
    bool public isICOFinalized = false;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public saleCount;
    uint256 public totalTokensSold;
    address[] public investors;
    bool public allowImmediateFinalization = false; 

    //mapping
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensBoughtByInvestor;

    // events
    event NewSaleCreated(uint256 saleId, uint256 startTime, uint256 endTime, uint256 tokenPrice);
    event TokensPurchased(address indexed buyer, uint256 saleId, uint256 amount);
    event ICOFinalized(uint256 totalTokensSold);
    event RefundInitiated(address indexed investor, uint256 amount);

    constructor(IERC20 _token, uint256 _softCap, uint256 _hardCap) Ownable(msg.sender) {
        token = _token;
        softCap = _softCap;
        hardCap = _hardCap;
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPrice
    ) external onlyOwner icoNotFinalized {
        require(_endTime > _startTime, "End time must be after start time");
        require(_startTime > getLatestSaleEndTime(), "New sale must start after the last sale ends");

        saleCount++;
        sales[saleCount] = Sale({
            startTime: _startTime,
            endTime: _endTime,
            tokenPrice: _tokenPrice,
            tokensSold: 0,
            isFinalized: false
        });

        emit NewSaleCreated(saleCount, _startTime, _endTime, _tokenPrice);
    }

    function buyTokens() external payable icoNotFinalized {
        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");

        Sale storage sale = sales[currentSaleId];
        uint256 tokensToBuy = (msg.value ) / sale.tokenPrice;
        require(totalTokensSold + tokensToBuy <= hardCap, "Purchase exceeds hard cap");

        contributions[msg.sender] += msg.value;
        sale.tokensSold += tokensToBuy;
        totalTokensSold += tokensToBuy;

        // Track investors and their purchases
        if (tokensBoughtByInvestor[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        tokensBoughtByInvestor[msg.sender] += tokensToBuy;

        emit TokensPurchased(msg.sender, currentSaleId, tokensToBuy);
    }

    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(bool _allow) external onlyOwner {
    allowImmediateFinalization = _allow; 
    }

    function getSoftCapReached() public view onlyOwner returns(bool){
        return (totalTokensSold >= softCap);
    }

    function getHardCapReached() public view onlyOwner returns(bool){
        return (totalTokensSold  == hardCap);
    }

    // function finalizeICO() public onlyOwner icoNotFinalized {
    //     require(totalTokensSold >= softCap || block.timestamp >= getLatestSaleEndTime(), "ICO not finalizable");

    //     isICOFinalized = true;
    //     token.transfer(owner(), address(this).balance);

    //     emit ICOFinalized(totalTokensSold);
    // }


function finalizeICO() public onlyOwner icoNotFinalized {
    require(
        totalTokensSold >= softCap || block.timestamp >= getLatestSaleEndTime(),
        "Cannot finalize: Soft cap not reached and sale is ongoing"
    );

    // if owner wants to finalize the ico just after reching the soft cap
    if (allowImmediateFinalization && totalTokensSold >= softCap) {
        isICOFinalized = true;
        payable(owner()).transfer(address(this).balance);
        emit ICOFinalized(totalTokensSold);
    }
    // owner wants to finalize the ico after the sales end and soft cap already reached 
     else {
        require(block.timestamp >= getLatestSaleEndTime() || totalTokensSold == hardCap, "Cannot finalize: Sale not ended or hard cap not reached");
        isICOFinalized = true;
        payable(owner()).transfer(address(this).balance);
        emit ICOFinalized(totalTokensSold);
    }
    }


    function initiateRefund() external onlyOwner icoNotFinalized {
        require(block.timestamp > getLatestSaleEndTime(), "ICO ongoing");
        require(totalTokensSold < softCap, "Soft cap reached");

        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contributions");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(amount);

        emit RefundInitiated(msg.sender, amount);
    }

    function airdropTokens() external onlyOwner {
        require(isICOFinalized, "ICO not finalized");

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 amount = tokensBoughtByInvestor[investor];
            if (amount > 0) {
                token.transfer(investor, amount);
            }
        }
    }

    function getCurrentSaleId() public view returns (uint256) {
        for (uint256 i = 1; i <= saleCount; i++) {
            if (block.timestamp >= sales[i].startTime && block.timestamp <= sales[i].endTime && !sales[i].isFinalized) {
                return i;
            }
        }
        return 0; // No active sale
    }

    function getLatestSaleEndTime() internal view returns (uint256) {
        uint256 latestEndTime;
        for (uint256 i = 1; i <= saleCount; i++) {
            if (sales[i].endTime > latestEndTime) {
                latestEndTime = sales[i].endTime;
            }
        }
        return latestEndTime;
    }
}
