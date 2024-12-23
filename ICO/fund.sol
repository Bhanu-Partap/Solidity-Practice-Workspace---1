// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Erc20.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ICO is Ownable, ReentrancyGuard {

    // Chainlink Price Feeds
    AggregatorV3Interface public priceFeedETH;
    AggregatorV3Interface public priceFeedBNB;
    AggregatorV3Interface public priceFeedUSDT;
    AggregatorV3Interface public priceFeedUSDC;


    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPriceUSD;
        uint256 tokensSold;
        bool isFinalized;
    }

    enum PaymentMethod {
        ETH,
        BNB,
        USDT,
        USDC
    }

    // State variables
    erc20token public token;
    uint256 public softCapInUSD;
    uint256 public hardCapInUSD;
    uint256 public saleCount;
    uint256 public totalFundsRaisedUSD;
    uint256 public totalTokensSold;
    bool public isICOFinalized = false;
    bool public isTokensAirdropped = false;
    bool public allowImmediateFinalization = false;
    address[] public investors;
    address usdt;
    address usdc;

    // Mappings
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256) public contributionsInUSD;
    mapping(address => uint256) public tokensBoughtByInvestor;
    mapping(address => AggregatorV3Interface) private priceFeeds;
    mapping(address => PaymentMethod) public paymentMethodForInvestor; 
    mapping(address => mapping(PaymentMethod => uint256)) public investorPayments;

    // Events
    event ICOFinalized(uint256 totalTokensSold);
    event ImmediateFinalization(uint256 saleId);
    event RefundInitiated(address investor, uint256 amount , PaymentMethod paymentMethod) ;
    event TokenAirdropped(address investor, uint256 airdroppedAmount);
    event TokensPurchased(
        address buyer,
        uint256 saleId,
        uint256 tokenPurchaseAmount,
        uint256 tokenPriceUSD,
        uint256 amountPaid,
        PaymentMethod paymentMethod
    );
    event NewSaleCreated(
        uint256 saleId,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenPriceUSD
    );

    constructor(
        erc20token _token,
        address _usdt,
        address _usdc,
        uint256 _softCapInUSD,
        uint256 _hardCapInUSD,
        address _priceFeedETH,
        address _priceFeedBNB,
        address _priceFeedUSDT,
        address _priceFeedUSDC
    ) Ownable(msg.sender) {
        token = _token;
        softCapInUSD = _softCapInUSD;
        hardCapInUSD = _hardCapInUSD;
        usdt = _usdt;
        usdc = _usdc;
        priceFeedETH = AggregatorV3Interface(_priceFeedETH);
        priceFeedBNB = AggregatorV3Interface(_priceFeedBNB);
        priceFeedUSDT = AggregatorV3Interface(_priceFeedUSDT);
        priceFeedUSDC = AggregatorV3Interface(_priceFeedUSDC);
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    function _getPriceFeed(PaymentMethod paymentMethod)
        public
        view
        returns (int256)
    {
        if (paymentMethod == PaymentMethod.ETH) {
            (, int256 price, , , ) = priceFeedETH.latestRoundData();
            return price;
        }

        if (paymentMethod == PaymentMethod.BNB) {
            (, int256 price, , , ) = priceFeedBNB.latestRoundData();
            return price;
        }

        if (paymentMethod == PaymentMethod.USDT) {
            (, int256 price, , , ) = priceFeedUSDT.latestRoundData();
            return price;
        }

        if (paymentMethod == PaymentMethod.USDC) {
            (, int256 price, , , ) = priceFeedUSDC.latestRoundData();
            return price;
        }
        revert("Unsupported payment method");
    }


    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPriceUSD
    ) external onlyOwner icoNotFinalized {
        require(
            _startTime > block.timestamp,
            "Start time must be greater than current time"
        );
        require(
            _endTime > _startTime,
            "End time must be greater than start time"
        );
        require(
            _startTime > getLatestSaleEndTime(),
            "New sale must start after the last sale ends"
        );

        saleCount++;
        sales[saleCount] = Sale({
            startTime: _startTime,
            endTime: _endTime,
            tokenPriceUSD: _tokenPriceUSD,
            tokensSold: 0,
            isFinalized: false
        });
        emit NewSaleCreated(saleCount, _startTime, _endTime, _tokenPriceUSD);
    }

    function calculateTokenAmount(
        PaymentMethod paymentMethod,
        uint256 paymentAmount   
    ) public view returns (uint256) {
        int256 price = _getPriceFeed(paymentMethod)*1e10;
        require(price > 0, "Invalid price feed");

        uint256 currentSaleId = getCurrentSaleId();
        Sale storage sale = sales[currentSaleId];

        uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Token price in (18 decimals)
        console.log("tokenPriceInUSD", tokenPriceInUSD);

        uint256 paymentAmountInUSD;

        if (paymentMethod == PaymentMethod.ETH || paymentMethod == PaymentMethod.BNB) {
            paymentAmountInUSD = (uint256(price) * paymentAmount) / 1e18;  
        } else if (paymentMethod == PaymentMethod.USDC || paymentMethod == PaymentMethod.USDT) {
        uint256 stablecoinDecimals = 6; 
        uint256 normalizedAmount = paymentAmount * (10**(18 - stablecoinDecimals)); 
        paymentAmountInUSD = (uint256(price) * normalizedAmount) / 1e18; 
        } else {
        revert("Unsupported payment method");
        }

        uint256 tokenAmount =(paymentAmountInUSD * 1e18)/ tokenPriceInUSD;
        return tokenAmount;
    }

    //Constructor Data
    // 100000000000000000000
    // 200000000000000000000
    // 0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7
    // 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
    // 0xEca2605f0BCF2BA5966372C99837b1F182d3D620
    // 0x90c069C4538adAc136E051052E14c1cD799C41B7


    function calculatePaymentAmount(PaymentMethod paymentMethod,uint256 tokenAmount) public view returns (uint256) {
    require(tokenAmount > 0, "Token amount must be greater than zero");

    int256 price = _getPriceFeed(paymentMethod) * 1e10; 
    require(price > 0, "Invalid price feed");

    uint256 currentSaleId = getCurrentSaleId();
    require(currentSaleId != 0, "No active sale");
    
    Sale storage sale = sales[currentSaleId];
    uint256 tokenPriceInUSD = sale.tokenPriceUSD;
    uint256 totalPaymentInUSD = (tokenAmount * tokenPriceInUSD) / 1e18;

    uint256 paymentAmount;
    if (paymentMethod == PaymentMethod.ETH || paymentMethod == PaymentMethod.BNB) {
        paymentAmount = (totalPaymentInUSD * 1e18) / uint256(price);
    } else if (paymentMethod == PaymentMethod.USDT || paymentMethod == PaymentMethod.USDC) {
        uint256 stablecoinDecimals = 6;
        uint256 normalizedAmount = (totalPaymentInUSD * (10**stablecoinDecimals)) / 1e18;
        paymentAmount = normalizedAmount;
    } else {
        revert("Unsupported payment method");
    }
    return paymentAmount;
}


    function buyTokens(PaymentMethod paymentMethod, uint256 paymentAmount) external payable icoNotFinalized {
    require(msg.sender != owner(), "Owner cannot buy tokens");
    uint256 currentSaleId = getCurrentSaleId();
    require(currentSaleId != 0, "No active sale");
    
    Sale storage sale = sales[currentSaleId];
    require(!sale.isFinalized, "Sale already finalized");

    uint256 tokenAmount;
    if (paymentMethod == PaymentMethod.BNB || paymentMethod == PaymentMethod.ETH) {
        // Handle native currency payments (ETH/BNB)
        require(msg.value > 0, "Send a valid ETH/BNB amount");
        tokenAmount = calculateTokenAmount(paymentMethod, msg.value);
        investorPayments[msg.sender][paymentMethod] += msg.value;
        console.log("Token amount for Native Payment:", tokenAmount);
    } else if (
        paymentMethod == PaymentMethod.USDT ||
        paymentMethod == PaymentMethod.USDC
    ) {
        // Handle stablecoin payments
        require(paymentAmount > 0, "Enter a valid stablecoin amount");
        IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
            ? IERC20(usdt)
            : IERC20(usdc);
        require(stablecoin.transferFrom(msg.sender,address(this),paymentAmount),"Stablecoin transfer failed");
        // Calculate token amount for stablecoin payment
        tokenAmount = calculateTokenAmount(paymentMethod, paymentAmount);
        investorPayments[msg.sender][paymentMethod] += paymentAmount;
        console.log("Token amount for Stablecoin Payment:", tokenAmount);
    } else {
        revert("Unsupported payment method");
    }
    require(tokenAmount > 0, "Invalid token amount");

    // Ensure the purchase does not exceed the hard cap
    uint256 totalCostInUSD = tokenAmount * sale.tokenPriceUSD / 1e18; 
    require(
        totalFundsRaisedUSD + totalCostInUSD <= hardCapInUSD,
        "Hard cap reached"
    );

    contributionsInUSD[msg.sender] += totalCostInUSD;
    totalFundsRaisedUSD += totalCostInUSD;
    sale.tokensSold += tokenAmount;
    totalTokensSold += tokenAmount;

    if (tokensBoughtByInvestor[msg.sender] == 0) {
        investors.push(msg.sender);
    }
    tokensBoughtByInvestor[msg.sender] += tokenAmount;
    paymentMethodForInvestor[msg.sender] = paymentMethod;

    emit TokensPurchased(
        msg.sender,
        currentSaleId,
        tokenAmount,
        sale.tokenPriceUSD,
        paymentAmount,
        paymentMethod
    );
}

    function finalizeSaleIfEnded(uint256 saleId) internal {
        Sale storage sale = sales[saleId];

        if (block.timestamp <= sale.endTime && !sale.isFinalized) {
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
            totalFundsRaisedUSD >= softCapInUSD || totalFundsRaisedUSD >= hardCapInUSD || block.timestamp >= getLatestSaleEndTime(),
            "Cannot finalize: Soft cap not reached or sale is ongoing"
        );

    // Finalize each sale if it has ended
    for (uint256 i = 1; i <= saleCount; i++) {
        Sale storage sale = sales[i];
        if (block.timestamp >= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
    }

    // If the hard cap has been reached, finalize immediately.
    if (totalFundsRaisedUSD >= hardCapInUSD) {
        isICOFinalized = true;
        _transferFundsToOwner();
        emit ICOFinalized(totalTokensSold);
    }
    // If the soft cap is reached but sale is not ended, finalize immediately if allowed.
    else if (totalFundsRaisedUSD >= softCapInUSD && allowImmediateFinalization) {
        isICOFinalized = true;
        _transferFundsToOwner();
        emit ICOFinalized(totalTokensSold);
    }
    // If the soft cap is reached and all sales are completed, finalize the ICO.
    else {
        require(block.timestamp >= getLatestSaleEndTime(), "Sale is still ongoing");
        isICOFinalized = true;
        _transferFundsToOwner();
        emit ICOFinalized(totalTokensSold);
    }
}

    function _transferFundsToOwner() private {
    // Transfer native funds (ETH/BNB)
    uint256 nativeBalance = address(this).balance;
    if (nativeBalance > 0) {
        (bool success, ) = payable(owner()).call{value: nativeBalance}("");
        require(success, "Transfer failed");
    }

    // Transfer stablecoin funds (USDT/USDC)
    uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
    if (usdtBalance > 0) {
        require(IERC20(usdt).transfer(owner(), usdtBalance), "USDT transfer failed");
    }

    uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
    if (usdcBalance > 0) {
        require(IERC20(usdc).transfer(owner(), usdcBalance), "USDC transfer failed");
    }
}

    function airdropTokens() external onlyOwner nonReentrant {
    require(!isTokensAirdropped, "Airdrop already completed");
    require(isICOFinalized, "ICO not finalized");

    uint256 investorLength = investors.length;
    for (uint256 i = 0; i < investorLength; i++) {
        address investor = investors[i];
        uint256 tokensBought = tokensBoughtByInvestor[investor];

        if (tokensBought > 0) {
            // Transfer the calculated token amount to the investor
            bool success = token.transferFrom(owner(), investor, tokensBought);
            require(success, "Token transfer failed");
            
            // Emit the token airdrop event
            emit TokenAirdropped(investor, tokensBought);
        }
    }

    isTokensAirdropped = true;
}

    function initiateRefund() external onlyOwner icoNotFinalized nonReentrant {
    require(block.timestamp > getLatestSaleEndTime() || allowImmediateFinalization, "Sale ongoing");
    require(totalFundsRaisedUSD < softCapInUSD, "Soft cap reached");

    uint256 investorLength = investors.length;
    for (uint256 i = 0; i < investorLength; i++) {
        address investor = investors[i];

        // Refund contributions for all payment methods
        for (uint8 j = 0; j < 4; j++) { 
            PaymentMethod paymentMethod = PaymentMethod(j);
            uint256 amount = investorPayments[investor][paymentMethod];

            if (amount > 0) {
                investorPayments[investor][paymentMethod] = 0;
                if (paymentMethod == PaymentMethod.BNB || paymentMethod == PaymentMethod.ETH) {
                    (bool sent, ) = payable(investor).call{value: amount}("");
                    require(sent, "ETH/BNB refund failed");
                } else if (paymentMethod == PaymentMethod.USDT || paymentMethod == PaymentMethod.USDC) {
                    IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
                        ? IERC20(usdt)
                        : IERC20(usdc);
                    require(
                        stablecoin.transfer(investor, amount),
                        "Stablecoin refund failed"
                    );
                } else {
                    revert("Unsupported payment method for refund");
                }
                emit RefundInitiated(investor, amount, paymentMethod);
            }
        }
    }
    isICOFinalized = true;
}

receive() external payable {
    revert("Direct ETH transfers not allowed");
}


    function getCurrentSaleId() public view returns (uint256) {
        for (uint256 i = 1; i <= saleCount; i++) {
            if (
                block.timestamp >= sales[i].startTime &&
                block.timestamp <= sales[i].endTime &&
                !sales[i].isFinalized
            ) {
                return i;
            }
        }
        return 0;
    }

    function getLatestSaleEndTime() internal view returns (uint256) {
        uint256 latestEndTime = 0;
        for (uint256 i = 1; i <= saleCount; i++) {
            if (sales[i].endTime > latestEndTime) {
                latestEndTime = sales[i].endTime;
            }
        }
        return latestEndTime;
    }

    function getSaleStartEndTime(uint256 _saleId)
        public
        view
        returns (uint256 _startTime, uint256 _endTime)
    {
        Sale memory sale = sales[_saleId];
        return (sale.startTime, sale.endTime);
    }

    function getSoftCapReached() public view returns (bool) {
        return (totalFundsRaisedUSD >= softCapInUSD);
    }

    function getHardCapReached() public view returns (bool) {
        return (totalFundsRaisedUSD >= hardCapInUSD);
    }

    function getInvestorCount() public view returns (uint256 investorCount) {
        investorCount = investors.length;
        return investorCount;
    }
}
