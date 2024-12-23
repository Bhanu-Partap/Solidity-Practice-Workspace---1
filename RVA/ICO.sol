// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./Vesting.sol";
import "./UpgradableToken.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ICO is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Chainlink Price Feeds
    AggregatorV3Interface public priceFeedBNB;
    // AggregatorV3Interface public priceFeedUSDT;
    // AggregatorV3Interface public priceFeedUSDC;

    struct Sale {
        uint256 startTime;      
        uint256 endTime;        
        // uint256 softCap;        
        uint256 hardCap;        
        uint256 tokenPrice;   //(USD)
        uint256 tokensSold;     
        // uint256 totalTokens;    
        bool isFinalized;    
        string saleName;   
}

    enum PaymentMethod {
        BNB
        // USDT,
        // USDC
    }

    // State variables
    ERC20Token public token;
    TokenVesting public vestingContract;
    uint256 public hardCapInUSD;
    uint256 public saleCount;
    uint256 public totalFundsRaisedUSD;
    uint256 public totalTokensSold;
    uint256 constant PRECISION_10 = 1e10;
    uint256 constant PRECISION_18 = 1e18;
    bool public isICOFinalized = false;
    bool public allowImmediateFinalization = false;
    address[] public investors;
    // address public immutable usdt;
    // address public immutable usdc;
    address public  vestingContractAddress;

    // Mappings
    mapping(uint256 => Sale) public sales;
    mapping(address => bool) public whitelistedUsers;
    mapping(address => uint256) public contributionsInUSD;
    // mapping(uint256 => mapping(address => uint256)) public tokensBoughtByInvestorForSale;
    mapping(address => AggregatorV3Interface) private priceFeeds;
    // mapping(address => PaymentMethod) public paymentMethodForInvestor; 
    mapping(address => mapping(PaymentMethod => uint256)) public investorPayments;

    // Events
    event Whitelisted(address indexed account);
    event ICOFinalized(uint256 totalTokensSold);
    event ImmediateFinalization(uint256 saleId);
    // event RefundInitiated(address investor, uint256 amount , PaymentMethod paymentMethod) ;
    // event TokensPurchased(address buyer, uint256 saleId, uint256 tokenPurchaseAmount, uint256 tokenPriceUSD,uint256 amountPaid, PaymentMethod paymentMethod);
    event RefundInitiated(address investor, uint256 amount ) ;
    event TokenAirdropped(address investor, uint256 airdroppedAmount);
    event TokensPurchased(address buyer, uint256 saleId, uint256 tokenPurchaseAmount, uint256 tokenPriceUSD,uint256 amountPaid);
    
    event NewSaleCreated(
        uint256 saleId,
        uint256 startTime,
        uint256 endTime,
        uint256 hardcap,
        uint256 tokenPriceUSD,
        string saleName
    );

    constructor(
        ERC20Token _token,
        // address _usdt,
        // address _usdc,
        uint256 _softCapInUSD,
        uint256 _hardCapInUSD,
        address _priceFeedBNB
    ) Ownable(msg.sender) {
        token = _token;
        hardCapInUSD = _hardCapInUSD;
        // usdt = _usdt;
        // usdc = _usdc;
        priceFeedBNB = AggregatorV3Interface(_priceFeedBNB);
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    modifier isWhitelisted() {
        require(whitelistedUsers[msg.sender], "Not a whitelisted user");
        _;
    }
// 
    function whitelistUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        whitelistedUsers[_user] = true;
        emit Whitelisted(_user);
    }

    function _getPriceFeed(PaymentMethod paymentMethod)
        public
        view
        returns (int256)
    {

        if (paymentMethod == PaymentMethod.BNB) {
            (, int256 price, , , ) = priceFeedBNB.latestRoundData();
            return price;
        }
        revert("Unsupported payment method");
    }

    //Constructor Data
    // 100000000000000000000
    // 200000000000000000000
    // 0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7
    // 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
    // 0xEca2605f0BCF2BA5966372C99837b1F182d3D620
    // 0x90c069C4538adAc136E051052E14c1cD799C41B7

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _hardCap,   
        uint256 _tokenPriceUSD, //(USD)
        uint256 _tokensSold,   
        bool _isFinalized,
        string memory _saleName
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
            hardcap:_hardCap,
            tokenPriceUSD: _tokenPriceUSD,
            tokensSold: 0,
            isFinalized: false,
            saleName:_saleName
        });
        emit NewSaleCreated(saleCount, _startTime, _endTime,_hardCap,_tokenPriceUSD,_saleName);
    }

    // function calculateTokenAmount(
    //     PaymentMethod paymentMethod,
    //     uint256 paymentAmount   
    // ) public view returns (uint256) {
    //     int256 price = _getPriceFeed(paymentMethod)*int256(PRECISION_10);
    //     require(price > 0, "Invalid price feed");

    //     uint256 currentSaleId = getCurrentSaleId();
    //     Sale storage sale = sales[currentSaleId];

    //     uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Token price in (18 decimals)

    //     uint256 paymentAmountInUSD;

    //     if (paymentMethod == PaymentMethod.BNB) {
    //         paymentAmountInUSD = (uint256(price) * paymentAmount) / uint256(PRECISION_18);  
    //     } else if (paymentMethod == PaymentMethod.USDC || paymentMethod == PaymentMethod.USDT) {
    //     uint256 stablecoinDecimals = 6; 
    //     uint256 normalizedAmount = paymentAmount * (10**(18 - stablecoinDecimals)); 
    //     paymentAmountInUSD = (uint256(price) * normalizedAmount) / uint256(PRECISION_18); 
    //     } else {
    //     revert("Unsupported payment method");
    //     }

    //     uint256 tokenAmount =(paymentAmountInUSD * uint256(PRECISION_18))/ tokenPriceInUSD;
    //     return tokenAmount;
    // }


// function calculatePaymentAmount(PaymentMethod paymentMethod, uint256 tokenAmount) public view returns (uint256) {
//     require(tokenAmount > 0, "Token amount must be greater than zero");

//     int256 price = _getPriceFeed(paymentMethod) * int256(PRECISION_10); // Price is now 18 decimals
//     require(price > 0, "Invalid price feed");

//     uint256 currentSaleId = getCurrentSaleId();
//     require(currentSaleId != 0, "No active sale");

//     Sale storage sale = sales[currentSaleId];
//     uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Assumes token price is in 18 decimals
//     uint256 totalPaymentInUSD = (tokenAmount * tokenPriceInUSD) / PRECISION_18;

//     uint256 paymentAmount;
//     if (paymentMethod == PaymentMethod.BNB) {
//         paymentAmount = (totalPaymentInUSD * PRECISION_18) / uint256(price);
//     } else if (paymentMethod == PaymentMethod.USDT || paymentMethod == PaymentMethod.USDC) {
//         paymentAmount = (totalPaymentInUSD * (10 ** 6)) / uint256(price);
//     } else {
//         revert("Unsupported payment method");
//     }

//     return paymentAmount;
// }


    function buyTokens() external payable icoNotFinalized {
    require(msg.sender != owner(), "Owner cannot buy tokens");
    uint256 currentSaleId = getCurrentSaleId();
    require(currentSaleId != 0, "No active sale");

    Sale storage sale = sales[currentSaleId];
    require(!sale.isFinalized, "Sale already finalized");

    // Check whitelist for restricted sales
    if (
        keccak256(abi.encodePacked(sale.name)) == keccak256("venture capital") ||
        keccak256(abi.encodePacked(sale.name)) == keccak256("private sale A") ||
        keccak256(abi.encodePacked(sale.name)) == keccak256("private sale B")
    ) {
        require(whitelistedUsers[msg.sender], "Only whitelisted users allowed");
    }

    // Ensure valid BNB payment
    require(msg.value > 0, "Send a valid BNB amount");
    uint256 tokenAmount = calculateTokenAmount(PaymentMethod.BNB, msg.value);
    require(tokenAmount > 0, "Invalid token amount");

    uint256 totalCostInUSD = (tokenAmount * sale.tokenPriceUSD) / PRECISION_18;
    require(
        totalFundsRaisedUSD + totalCostInUSD <= hardCapInUSD,
        "Hard cap reached"
    );

    // Update contributions and sales data
    investorPayments[msg.sender][PaymentMethod.BNB] += msg.value;
    contributionsInUSD[msg.sender] += totalCostInUSD;
    totalFundsRaisedUSD += totalCostInUSD;
    sale.tokensSold += tokenAmount;
    totalTokensSold += tokenAmount;

    tokensBoughtByInvestorForSale[currentSaleId][msg.sender] += tokenAmount;

    if (tokensBoughtByInvestor[msg.sender] == 0) {
        investors.push(msg.sender);
    }
    tokensBoughtByInvestor[msg.sender] += tokenAmount;

    emit TokensPurchased(
        msg.sender,
        currentSaleId,
        tokenAmount,
        sale.tokenPriceUSD,
        msg.value,
        PaymentMethod.BNB
    );

    // Call setLockup in the vesting contract based on the sale
    uint256 initialRelease;
    uint256 lockedTokens;
    if (keccak256(abi.encodePacked(sale.name)) == keccak256("venture capital")) {
        
        // Lockup logic for venture capital sale
        initialRelease = (tokenAmount * 5) / 100; // 5% initial release
        lockedTokens = tokenAmount - initialRelease;

        // Set lockup: 12-month lockup for 95% of tokens with 24-month vesting
        vestingContract.registerVesting(
            msg.sender,
            sale,
            lockedTokens,
            block.timestamp,
            1 years, // lockup period
            2 years // vesting period
        );
    } else if (
        keccak256(abi.encodePacked(sale.name)) == keccak256("private sale A") 
    ){
        // Lockup logic for Private Sale A
        initialRelease = (tokenAmount * 10) / 100; // 10% initial release
        lockedTokens = tokenAmount - initialRelease;

        // Set lockup: 6-month lockup for 90% of tokens with 18-month vesting
        vestingContract.registerVesting(
            msg.sender,
            sale,
            lockedTokens,
            block.timestamp,
            0.5 years,  // lockup period
            1.5 years  // vesting period
        );
    }
    else if(keccak256(abi.encodePacked(sale.name)) == keccak256("private sale B") ){

         // Lockup logic for Private Sale B
        initialRelease = (tokenAmount * 15) / 100; // 15% initial release
        lockedTokens = tokenAmount - initialRelease;

        // Set lockup: 3-month lockup for 90% of tokens with 12-month vesting
        vestingContract.registerVesting(
            msg.sender,
            sale,
            lockedTokens,
            block.timestamp,
            0.25 years,  // lockup period
            1 years    // vesting period
        );
    } 
    else if(keccak256(abi.encodePacked(sale.name)) == keccak256("public sale")) {

        // Lockup logic for Public Sale
        initialRelease = (tokenAmount * 25) / 100; // 25% initial release
        lockedTokens = tokenAmount - initialRelease;

        // Set lockup: 75% of tokens with 6-month vesting
        vestingContract.registerVesting(
            msg.sender,
            sale,
            lockedTokens,
            block.timestamp,
            0,    // lockup period
            0.5 years   // vesting period
        );
    }
}


    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(uint256 saleId, bool _allow) public onlyOwner {
        allowImmediateFinalization = _allow; 
        Sale storage sale = sales[saleId];

        if (block.timestamp <= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
        emit ImmediateFinalization(saleId);
    }

    function finalizeICO() public nonReentrant onlyOwner icoNotFinalized {
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

    function initiateRefund() external nonReentrant onlyOwner icoNotFinalized  {
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
                if (paymentMethod == PaymentMethod.BNB ) {
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
    revert("Direct BNB transfers not allowed");
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