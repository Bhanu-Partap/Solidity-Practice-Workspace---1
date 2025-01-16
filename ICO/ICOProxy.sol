// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract ENCRYPTEDCASHICO is ReentrancyGuardUpgradeable ,OwnableUpgradeable, UUPSUpgradeable {
    // Chainlink Price Feeds
    AggregatorV3Interface private priceFeedBNB;
    AggregatorV3Interface private priceFeedUSDT;
    AggregatorV3Interface private priceFeedUSDC;

    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPriceUSD;
        uint256 tokensSold;
        bool isFinalized;
    }

    enum PaymentMethod {
        BNB,
        USDT,
        USDC
    }

    // State variables
    IERC20 public token;
    uint256 public softCapInUSD;
    uint256 public hardCapInUSD;
    uint256 public saleCount;
    uint256 public totalFundsRaisedUSD;
    uint256 public totalTokensSold;
    uint256 constant PRECISION_10 = 1e10;
    uint256 constant PRECISION_18 = 1e18;
    bool public isICOFinalized ;
    bool public isTokensAirdropped;
    bool public isFreezed ;

    address[] public investors;
    address public usdt;
    address public usdc;

    // Mappings
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256) public contributionsInUSD;
    mapping(address => uint256) public tokensBoughtByInvestor;
    mapping(address => PaymentMethod) private paymentMethodForInvestor;
    mapping(address => mapping(PaymentMethod => uint256))private investorPayments;

    // Events
    event ICOFinalized(uint256 indexed totalTokensSold);
    event ImmediateFinalization(uint256 indexed saleId);
    event RefundInitiated(
        address indexed investor,
        uint256 amount,
        PaymentMethod paymentMethod
    );
    event TokenAirdropped(address indexed investor, uint256 airdroppedAmount);
    event TokensPurchased(
        address indexed buyer,
        uint256 indexed saleId,
        uint256 tokenPurchaseAmount,
        uint256 tokenPriceUSD,
        uint256 amountPaid,
        PaymentMethod paymentMethod
    );
    event NewSaleCreated(
        uint256 indexed saleId,
        uint256 startTime,
        uint256 endTime,
        uint256 tokenPriceUSD
    );

    function initialize(
        IERC20 _token,
        address _usdt,
        address _usdc,
        uint256 _softCapInUSD,
        uint256 _hardCapInUSD,
        address _priceFeedBNB,
        address _priceFeedUSDT,
        address _priceFeedUSDC
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init(); 
        token = _token;
        softCapInUSD = _softCapInUSD;
        hardCapInUSD = _hardCapInUSD;
        usdt = _usdt;
        usdc = _usdc;
        priceFeedBNB = AggregatorV3Interface(_priceFeedBNB);
        priceFeedUSDT = AggregatorV3Interface(_priceFeedUSDT);
        priceFeedUSDC = AggregatorV3Interface(_priceFeedUSDC);
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    modifier freezed() {
        require(!isFreezed, "freezed");
        _;
    }

    function freeze() external onlyOwner freezed {
        // require(!isFreezed ,"Already Freezed");
        isFreezed = true;
    }

    function unFreeze() external onlyOwner {
        require(isFreezed ,"Already UnFreezed");
        isFreezed = false;
    }

    function _getPriceFeed(PaymentMethod paymentMethod)
        public
        view
        returns (int256)
    {
        if (paymentMethod == PaymentMethod.BNB) {
            (, int256 price, , , ) = priceFeedBNB.latestRoundData();
            return price;
        } else if (paymentMethod == PaymentMethod.USDT) {
            (, int256 price, , , ) = priceFeedUSDT.latestRoundData();
            return price;
        } else if (paymentMethod == PaymentMethod.USDC) {
            (, int256 price, , , ) = priceFeedUSDC.latestRoundData();
            return price;
        } else {
            revert("Unsupported payment method");
        }
    }

    function precision_mul_10(uint val) public pure returns(uint){
        return  val * 1e10;
    }

    function precision_mul_18(uint val) public pure returns(uint){
        return  val * 1e18;
    }
    function precision_div_10(uint val) public pure returns(uint){
        return  val / 1e10;
    }
    function precision_div_18(uint val) public pure returns(uint){
        return  val / 1e18;
    }

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPriceUSD
    ) external nonReentrant onlyOwner icoNotFinalized freezed {
        require(
           _startTime > block.timestamp && _endTime > _startTime && block.timestamp > getLatestSaleEndTime(),
            "Invalid start time range"
        );
        saleCount = saleCount +1;
        Sale storage sale = sales[saleCount];
            sale.startTime = _startTime;
            sale.endTime = _endTime;
            sale.tokenPriceUSD = _tokenPriceUSD;
            sale.tokensSold = 0;
            sale.isFinalized = false;
        emit NewSaleCreated(saleCount, _startTime, _endTime, _tokenPriceUSD);
    }

    function calculateTokenAmount(
        PaymentMethod paymentMethod,
        uint256 paymentAmount
    ) public view returns (uint256) {
        uint256 price = precision_mul_10(uint(_getPriceFeed(paymentMethod))) ;
        require(price != 0, "Invalid price feed");
        uint256 currentSaleId = getCurrentSaleId();
        Sale storage sale = sales[currentSaleId];

        uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Token price in (18 decimals)

        uint256 paymentAmountInUSD;

        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmountInUSD =
                precision_div_18(uint256(price) * paymentAmount);
        } else if (
            paymentMethod == PaymentMethod.USDC ||
            paymentMethod == PaymentMethod.USDT
        ) {
            uint256 stablecoinDecimals = 6;
            uint256 normalizedAmount = paymentAmount *
                (10**(18 - stablecoinDecimals));
            paymentAmountInUSD =
                precision_div_18(uint256(price) * normalizedAmount);
        } else {
            revert("Unsupported payment method");
        }

        uint256 tokenAmount = precision_mul_18(paymentAmountInUSD) /
            tokenPriceInUSD;
        return tokenAmount;
    }

    function calculatePaymentAmount(
        PaymentMethod paymentMethod,
        uint256 tokenAmount
    ) external view returns (uint256) {
        require(tokenAmount != 0, "Amount must be positive");

        uint256 price = precision_mul_10(uint(_getPriceFeed(paymentMethod))); 
        require(price != 0, "Invalid price feed");

        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");
        Sale storage sale = sales[currentSaleId];
        uint256 tokenPriceInUSD = sale.tokenPriceUSD; 
        uint256 totalPaymentInUSD = precision_div_18(tokenAmount * tokenPriceInUSD);

        uint256 paymentAmount;
        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmount = precision_mul_18(totalPaymentInUSD) / uint256(price);
        } else if (
            paymentMethod == PaymentMethod.USDT ||
            paymentMethod == PaymentMethod.USDC
        ) {
            paymentAmount = (totalPaymentInUSD * (10**6)) / uint256(price);
        } else {
            revert("Unsupported payment method");
        }

        return paymentAmount;
    }

    function buyTokens(PaymentMethod paymentMethod, uint256 paymentAmount)
        external
        payable
        
        nonReentrant
        icoNotFinalized
        freezed
    {
        require(msg.sender != owner(), "Owner cannot buy tokens");
        require(saleCount != 0, "No sale");
        require(!sales[saleCount].isFinalized, "Sale already finalized");
        uint256 tokenAmount;
        if (paymentMethod == PaymentMethod.BNB) {
            require(msg.value != 0, "Send a valid BNB amount");
            tokenAmount = calculateTokenAmount(paymentMethod, msg.value);
            investorPayments[msg.sender][paymentMethod] += msg.value;
        } else if (
            paymentMethod == PaymentMethod.USDT ||
            paymentMethod == PaymentMethod.USDC
        ) {
            require(paymentAmount != 0, "Enter valid amount");
            IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
                ? IERC20(usdt)
                : IERC20(usdc);
            require(
                stablecoin.transferFrom(
                    msg.sender,
                    address(this),
                    paymentAmount
                ),
                "Stablecoin transfer failed"
            );
            tokenAmount = calculateTokenAmount(paymentMethod, paymentAmount);
            investorPayments[msg.sender][paymentMethod] += paymentAmount;
        }
         
        require(tokenAmount != 0, "Invalid token amount");
        uint256 totalCostInUSD = (tokenAmount *
            sales[saleCount].tokenPriceUSD) / PRECISION_18;
        require(
            totalFundsRaisedUSD + totalCostInUSD <= hardCapInUSD,
            "Hard cap reached"
        );
        contributionsInUSD[msg.sender] =contributionsInUSD[msg.sender]+ totalCostInUSD;
        totalFundsRaisedUSD = totalFundsRaisedUSD+ totalCostInUSD;
        sales[saleCount].tokensSold += tokenAmount;
        totalTokensSold = totalTokensSold+ tokenAmount;

        if (tokensBoughtByInvestor[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        tokensBoughtByInvestor[msg.sender] =tokensBoughtByInvestor[msg.sender]+ tokenAmount;
        paymentMethodForInvestor[msg.sender] = paymentMethod;

        emit TokensPurchased(
            msg.sender,
            saleCount,
            tokenAmount,
            sales[saleCount].tokenPriceUSD,
            paymentAmount,
            paymentMethod
        );
    }

    function finalizeICO()
        public
        nonReentrant
        onlyOwner
        icoNotFinalized
        freezed
    {
        require(
            totalFundsRaisedUSD >= softCapInUSD,
            "Soft Cap NOt Reached"
        );
        require(isTokensAirdropped, "Airdrop not completed");

        isICOFinalized = true;
        _transferFundsToOwner();
        emit ICOFinalized(totalTokensSold);
    }

    function _transferFundsToOwner() private{
        address self = address(this);
        uint256 nativeBalance = self.balance;
        if (nativeBalance != 0) {
            (bool success, ) = payable(owner()).call{value: nativeBalance}("");
            require(success, "Transfer failed");
        }
        uint256 usdtBalance = IERC20(usdt).balanceOf(self);
        if (usdtBalance != 0) {
            require(
                IERC20(usdt).transfer(owner(), usdtBalance),
                "USDT transfer failed"
            );
        }
        uint256 usdcBalance = IERC20(usdc).balanceOf(self);
        if (usdcBalance != 0) {
            require(
                IERC20(usdc).transfer(owner(), usdcBalance),
                "USDC transfer failed"
            );
        }
    }

    function airdropTokens()
        external
        nonReentrant
        onlyOwner
        icoNotFinalized
        freezed
    {
        require(!isTokensAirdropped, "Airdrop already completed");
        require(
            token.balanceOf(msg.sender) >= totalTokensSold,
            "Insufficient Funds"
        );
        require(block.timestamp > getLatestSaleEndTime(), "Sale ongoing");

        uint256 investorLength = investors.length;
        uint256 investorsIterated;

        if (investorLength > 10) {
            investorsIterated = investorLength - 11;
        } else {
            investorsIterated = 0;
        }
        for (uint256 i = investorLength - 1; i >= investorsIterated; i--) {
            address investor = investors[i];
            uint256 tokensBought = tokensBoughtByInvestor[investor];

            if (tokensBought > 0) {
                require(token.transferFrom(
                    owner(),
                    investor,
                    tokensBought
                ), "Token transfer failed");
                investors.pop();
                emit TokenAirdropped(investor, tokensBought);
            }
            if (i == 0) {
                break;
            }
        }
        if (investors.length == 0) {
            isTokensAirdropped = true;
        }
    }

    function initiateRefund() external nonReentrant onlyOwner icoNotFinalized {
        require(block.timestamp > getLatestSaleEndTime(), "Sale ongoing");
        require(totalFundsRaisedUSD < softCapInUSD, "Soft cap reached");

        uint256 investorLength = investors.length;
        uint256 investorsIterated;

        if (investorLength > 10) {
            investorsIterated = investorLength - 11;
        } else {
            investorsIterated = 0;
        }

        for (uint256 i = investorLength - 1; i >= investorsIterated; i--) {
            address investor = investors[i];
            for (uint8 j = 0; j < 3; j++) {
                PaymentMethod paymentMethod = PaymentMethod(j);
                uint256 amount = investorPayments[investor][paymentMethod];

                if (amount > 0) {
                    investorPayments[investor][paymentMethod] = 0;
                    if (paymentMethod == PaymentMethod.BNB) {
                        (bool sent, ) = payable(investor).call{value: amount}(
                            ""
                        );
                        require(sent, "BNB refund failed");
                    } else if (
                        paymentMethod == PaymentMethod.USDT ||
                        paymentMethod == PaymentMethod.USDC
                    ) {
                        IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
                            ? IERC20(usdt)
                            : IERC20(usdc);
                        require(
                            stablecoin.transfer(investor, amount),
                            "Stablecoin refund failed"
                        );
                        
                    }
                    
                    emit RefundInitiated(investor, amount, paymentMethod);
                }
                
            }
            investors.pop();
            if (i == 0) {
                    break;
                }
        }
        if (investors.length == 0) {
            isICOFinalized = true;
        }
    }

    receive() external payable {
        revert("Direct BNB transfers not allowed");
    }

    function getCurrentSaleId() public view returns (uint256) {
        return saleCount;
    }

    function getLatestSaleEndTime() internal view returns (uint256) {
        return sales[saleCount].endTime;
    }

    function getSaleStartEndTime(uint256)
        public
        view
        returns (uint256 _startTime, uint256 _endTime)
    {
        Sale memory sale = sales[saleCount];
        return (sale.startTime, sale.endTime);
    }

    function getSoftCapReached() public view returns (bool) {
        return (totalFundsRaisedUSD >= softCapInUSD);
    }

    function getHardCapReached() public view returns (bool) {
        return (totalFundsRaisedUSD == hardCapInUSD);
    }

    function getInvestorCount() public view returns (uint256 investorCount) {
        investorCount = investors.length;
        return investorCount;
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}