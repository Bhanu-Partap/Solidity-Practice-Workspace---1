// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Erc20.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ICO is Ownable,ReentrancyGuard {
    AggregatorV3Interface internal bnbUsdPriceFeed;

    // Struct
    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice; 
        uint256 tokensSold;
        bool isFinalized; 
    }

    // State variables
    erc20token public token;
    uint256 public softCapInFunds;
    uint256 public hardCapInFunds; 
    uint256 public saleCount;
    uint256 public totalFundsRaised; 
    uint256 public totalTokensSold;
    // uint256 public tokenPriceInUSD;
    bool public isICOFinalized = false;
    bool public isTokensAirdropped = false;
    bool public allowImmediateFinalization = false; 
    address[] public investors;


    // Mappings
    mapping(uint256 => Sale) public sales;
    // mapping(address => bool) public whitelisted;
    mapping(address => uint256) public contributions;  
    mapping(address => bool) public acceptedStablecoins;
    mapping(address => uint256) public tokensBoughtByInvestor; 
    mapping(address => uint256) public stablecoinContributions;

    //events
    // event Whitelisted(address indexed account);
    event ICOFinalized(uint256 totalTokensSold);
    event ImmediateFinalization(uint256 saleId);
    event RefundInitiated(address investor, uint256 amount);
    event tokenAirdropped(address investor, uint256 airdroppedAmount);
    event TokensPurchased(address buyer, uint256 saleId, uint256 tokenPurchaseAmount, uint256 tokenPrice, uint256 amountPaid);
    event NewSaleCreated(uint256 saleId, uint256 startTime, uint256 endTime, uint256 tokenPrice);


    constructor( address _bnbUsdPriceFeed, erc20token _token,uint256 _softCapInFunds, uint256 _hardCapInFunds) Ownable(msg.sender) {
        token = _token;
        bnbUsdPriceFeed = AggregatorV3Interface(address(_bnbUsdPriceFeed));
        softCapInFunds = _softCapInFunds;
        hardCapInFunds = _hardCapInFunds;
    }

    function getBnbUsdPrice() public view returns (uint256) {
        (, int256 price, , , ) = bnbUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price); // BNB price in USD with 8 decimals
    }
// 5000000000000000

    function addStablecoin(address _stablecoin) external onlyOwner {
        acceptedStablecoins[_stablecoin] = true;
    }

    function removeStablecoin(address _stablecoin) external onlyOwner {
        acceptedStablecoins[_stablecoin] = false;
    }

    // modifier isWhitelisted() {
    //     require(whitelisted[msg.sender], "Not a whitelisted user");
    //     _;
    // }

    // function whitelistUser(address _user) external onlyOwner {
    //     require(_user != address(0), "Invalid address");
    //     whitelisted[_user] = true;
    //     emit Whitelisted(_user);
    // }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPrice
    ) external onlyOwner icoNotFinalized {
        require(_startTime > block.timestamp, "Start time must be greater than current time");
        require(_endTime > _startTime, "End time must be greater than start time");
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

    function buyTokensWithBNB() external payable nonReentrant {
        uint256 currentSaleId = getCurrentSaleId();
        Sale storage sale = sales[currentSaleId];
        require(!sale.isFinalized, "Sale already finalized");
    // require(
    //     block.timestamp >= currentSale.startTime && block.timestamp <= currentSale.endTime,
    //     "Sale not active"
    // );
    require(msg.value > 0, "Send BNB to buy tokens");

    uint256 bnbUsdPrice = getBnbUsdPrice(); // Get BNB/USD price
    uint256 tokenPriceInUsd = (sale.tokenPrice * bnbUsdPrice) / 10**18; // Token price in USD

    uint256 tokensToBuy = (msg.value * bnbUsdPrice * 1e18) / (tokenPriceInUsd * 1e18);
    require(tokensToBuy > 0, "Insufficient BNB for tokens");

    // Update state variables
    if (tokenBalances[msg.sender] == 0) {
        investors.push(msg.sender); // Track new investor
    }
    bnbContributions[msg.sender] += msg.value; // Update BNB contributions
    tokenBalances[msg.sender] += tokensToBuy;  // Update token allocation

    currentSale.tokensSold += tokensToBuy;
    totalTokensSold += tokensToBuy;

    emit TokensPurchased(msg.sender, tokensToBuy, msg.value, address(0)); // address(0) for BNB
}




















    // // if using whitelisting mechanism then add isWhitelisted modifier in buy token funtion
    // function buyTokens() external payable icoNotFinalized {
    //     require(msg.sender != owner(), "Owner cannot buy tokens");
    //     uint256 currentSaleId = getCurrentSaleId();
    //     require(currentSaleId != 0, "No active sale");
    //     require(msg.value > 0, "Enter a valid amount");

    //     // Finalize previous sales
    //     for (uint256 i = 1; i <= saleCount; i++) {
    //         finalizeSaleIfEnded(i);
    //     }

    //     // 61268230870 ** 10^18/ usd decimal


    //     Sale storage sale = sales[currentSaleId];
    //     require(!sale.isFinalized, "Sale already finalized");
    //     uint256 tokenDecimals = 10 ** erc20token(token).decimals();

    //     uint256 tokenPrice = sale.tokenPrice;                                                                                                           
    //     require(msg.value % tokenPrice == 0, "Amount must be equal or multiple of the token price");

    //     uint256 tokensToBuy = (msg.value/ tokenPrice) * uint256(tokenDecimals);
    //     require(totalFundsRaised + msg.value <= hardCapInFunds, "Purchase exceeds hard cap in funds");

    //     contributions[msg.sender] += msg.value;
    //     totalFundsRaised += msg.value;
    //     sale.tokensSold += tokensToBuy;
    //     totalTokensSold += tokensToBuy;

    //     // Track investors and their purchases
    //     if (tokensBoughtByInvestor[msg.sender] == 0) {
    //         investors.push(msg.sender);
    //     }
    //     tokensBoughtByInvestor[msg.sender] += tokensToBuy;

    //     emit TokensPurchased(msg.sender, currentSaleId, tokensToBuy, tokenPrice, msg.value);
    // }



    // function buyTokenStablecoin(address _stablecoin, uint256 amount) external payable icoNotFinalized{
    //     require(acceptedStablecoins[_stablecoin], "Stablecoin not accepted");
    //     require(msg.sender != owner(), "Owner cannot buy tokens");
    //     require(_stablecoin !=address(0),"Invalid token address");
    //     uint256 currentSaleId = getCurrentSaleId();
    //     require(currentSaleId != 0, "No active sale");
    //     require(amount > 0, "Enter a valid amount");

    //     for (uint256 i = 1; i <= saleCount; i++) {
    //         finalizeSaleIfEnded(i);
    //     }

    //     Sale storage sale = sales[currentSaleId];
    //     require(!sale.isFinalized, "Sale already finalized");
    //     uint256 tokenPriceInBnb = sale.tokenPrice; 

    //     uint256 bnbUsdPrice = 63261256000; // Get BNB/USD price
    //     uint256 tokenPriceInUsd = (tokenPriceInBnb * bnbUsdPrice) / 10**18; // Token price in USD

    //     uint256 tokensToBuy = (amount * 10**18) / tokenPriceInUsd;
    //     require(tokensToBuy > 0, "Insufficient stablecoin for tokens");

    //     bool success = IERC20(_stablecoin).transferFrom(msg.sender, address(this), amount);
    //     require(success, "Stablecoin transfer failed");

    //     require(totalFundsRaised + msg.value <= hardCapInFunds, "Purchase exceeds hard cap in funds");

    //     stablecoinContributions[msg.sender] += amount;
    //     totalFundsRaised += amount;
    //     sale.tokensSold += tokensToBuy;
    //     totalTokensSold += tokensToBuy;

    // if (tokensBoughtByInvestor[msg.sender] == 0) {
    //     investors.push(msg.sender); // Track new investor
    // }

    // emit TokensPurchased(msg.sender, currentSaleId, tokensToBuy, tokenPriceInUsd, amount);
    // }

    




    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }


    function finalizeSaleIfEnded(uint256 saleId) internal {
        Sale storage sale = sales[saleId];

        if (block.timestamp >= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
    }

    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(uint256 saleId, bool _allow) public onlyOwner {
        allowImmediateFinalization = _allow; 
        finalizeSaleIfEnded(saleId);
        emit ImmediateFinalization(saleId);
    }

    function finalizeICO() public onlyOwner icoNotFinalized nonReentrant {
        require(
            totalFundsRaised >= softCapInFunds || totalFundsRaised >= hardCapInFunds || block.timestamp >= getLatestSaleEndTime(),
            "Cannot finalize: Soft cap not reached or sale is ongoing"
        );

        for (uint256 i = 1; i <= saleCount; i++) {
            Sale storage sale = sales[i];
            if (block.timestamp >= sale.endTime && !sale.isFinalized) {
                sale.isFinalized = true;
            }
        }

        // If the hard cap has been reached, finalize immediately.
        if (totalFundsRaised >= hardCapInFunds) {
            isICOFinalized = true;
            payable(owner()).transfer(address(this).balance);
            emit ICOFinalized(totalTokensSold);
        }
        // If the soft cap is reached but sale is not ended, the owner can finalize immediately if allowed.
        else if (totalFundsRaised >= softCapInFunds && allowImmediateFinalization) {
            isICOFinalized = true;
            payable(owner()).transfer(address(this).balance);
            emit ICOFinalized(totalTokensSold);
        }
        // If the soft cap is reached and all sales are completed, finalize the ICO.
        else {
            require(block.timestamp >= getLatestSaleEndTime(), "Sale is still ongoing");
            isICOFinalized = true;
            payable(owner()).transfer(address(this).balance);
            emit ICOFinalized(totalTokensSold);
        }
    }

    function initiateRefund() external onlyOwner icoNotFinalized nonReentrant{
        require(block.timestamp > getLatestSaleEndTime() || allowImmediateFinalization, "Sale ongoing");
        require(totalFundsRaised < softCapInFunds, "Soft cap reached");
        uint256 investorLength=investors.length;
        for (uint256 i = 0; i < investorLength; i++) {
            address investor = investors[i];
            uint256 amount = contributions[investor];

            if (amount > 0) {
                contributions[investor] = 0; // resetting the mapping before the transfer (reentrancy)
                payable(investor).transfer(amount); 
                emit RefundInitiated(investor, amount);
            }
        }
        isICOFinalized = true;
    }

    function airdropTokens() external onlyOwner nonReentrant{
        require(!isTokensAirdropped, "Airdrop already completed");
        require(isICOFinalized, "ICO not finalized");
        uint256 investorLength=investors.length;
        for (uint256 i = 0; i < investorLength; i++) {
            address investor = investors[i];
            uint256 tokensBought = tokensBoughtByInvestor[investor] ;
            if (tokensBought > 0) {
                bool success = token.transferFrom(owner(), investor, tokensBought);
                require(success, "Token transfer failed");
                emit tokenAirdropped(investor, tokensBought);
            }
        }
        isTokensAirdropped = true;
    }

    // Getter Functions
    function getCurrentSaleId() public view returns (uint256) {
        for (uint256 i = 1; i <= saleCount; i++) {
            if (block.timestamp >= sales[i].startTime && block.timestamp <= sales[i].endTime && !sales[i].isFinalized) {
                return i;
            }
        }
        return 0;
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

    function getSaleStartEndTime(uint256 _saleId) public view returns(uint256 _startTime, uint256 _endTime) {
        Sale memory sale = sales[_saleId];
        return (sale.startTime, sale.endTime);
    }

    function getSoftCapReached() public view returns(bool) {
        return (totalFundsRaised >= softCapInFunds);
    }

    function getHardCapReached() public view returns(bool) {
        return (totalFundsRaised >= hardCapInFunds);
    }

    function getInvestorCount() public view returns(uint256 investorCount){
        investorCount = investors.length;
        return investorCount ;
    }
}
