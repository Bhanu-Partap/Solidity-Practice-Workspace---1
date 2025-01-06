// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./Vesting.sol";
import "./UpgradableToken.sol";
import "./IdentityFactory.sol";
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
        uint256 softCap;
        uint256 hardCap;
        uint256 tokenPrice; //(USD)
        uint256 tokensSold;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        string saleName;
        bool isFinalized;
    }

    enum PaymentMethod {
        BNB
        // USDT,
        // USDC
    }

    // State variables
    ERC20Token public token;
    IDfactory public IdentityContract;
    TokenVesting public vestingContract;
    // uint256 public hardCapInUSD;
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
    // address public  vestingContractAddress;

    // Mappings
    mapping(uint256 => Sale) public sales;
    mapping(address => bool) public whitelistedUsers;
    mapping(address => bool) public blacklistedUsers;
    mapping(address => uint256) public contributionsInUSD;
    mapping(address => uint256) public tokensBoughtByInvestor;
    mapping(address => AggregatorV3Interface) private priceFeeds;
    mapping(address => mapping(PaymentMethod => uint256))
        public investorPayments;
    mapping(uint256 => mapping(address => uint256))
        public tokensBoughtByInvestorForSale;
    // mapping(address => PaymentMethod) public paymentMethodForInvestor;

    // Events
    event Whitelisted(address indexed account);
    event Blacklisted(address indexed account);
    // event BatchWhitelisted(address[] users);
    event ICOFinalized(uint256 indexed totalTokensSold);
    event ImmediateFinalization(uint256 indexed saleId);
    // event RefundInitiated(address investor, uint256 amount , PaymentMethod paymentMethod) ;
    event TokensPurchased(
        address buyer,
        uint256 saleId,
        uint256 tokenPurchaseAmount,
        uint256 tokenPriceUSD,
        uint256 amountPaid,
        PaymentMethod paymentMethod
    );
    event RefundClaimed(address indexed investor, uint256 amount);
    // event TokenAirdropped(address investor, uint256 airdroppedAmount);
    // event TokensPurchased(address indexed buyer, uint256 saleId, uint256 tokenPurchaseAmount, uint256 tokenPriceUSD,uint256 amountPaid);

    event NewSaleCreated(
        uint256 indexed saleId,
        uint256 startTime,
        uint256 endTime,
        uint256 softCap,
        uint256 hardcap,
        uint256 tokenPriceUSD,
        string saleName,
        uint256 minPurchaseAmount,
        uint256 maxPurchaseAmount
    );

    constructor(
        ERC20Token _token,
        TokenVesting _vestingContract,
        IDfactory _identityContract,
        // address _usdt,
        // address _usdc,
        // uint256 _softCapInUSD,
        // uint256 _hardCapInUSD,
        address _priceFeedBNB
    ) Ownable(msg.sender) {
        token = _token;
        vestingContract = _vestingContract;
        IdentityContract = _identityContract;
        // hardCapInUSD = _hardCapInUSD;
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

    function whitelistUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        whitelistedUsers[_user] = true;
        emit Whitelisted(_user);
    }

    function blacklistUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        blacklistedUsers[_user] = true;
        emit Blacklisted(_user);
    }

    // function batchWhitelistUsers(address[] calldata _users) external onlyOwner {
    // require(_users.length > 0, "No addresses provided");
    // uint256 userLength = _users.length;
    // for (uint256 i = 0; i < userLength; i++) {
    //     address user = _users[i];
    //     require(user != address(0), "Invalid address in batch");
    //     require(!whitelistedUsers[user], "Duplicate/Existing address in batch");
    //     whitelistedUsers[user] = true;
    // }
    // emit BatchWhitelisted(_users);
    // }

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
    // 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _tokenPriceUSD, //(USD)
        uint256 _minPurchaseAmount,
        uint256 _maxPurchaseAmount,
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
        require(_tokenPriceUSD > 0, "Price can't be zero");

        saleCount++;
        sales[saleCount] = Sale({
            startTime: _startTime,
            endTime: _endTime,
            softCap: _softCap,
            hardcap: _hardCap,
            tokenPriceUSD: _tokenPriceUSD,
            tokensSold: 0,
            minPurchaseAmount: _minPurchaseAmount,
            maxPurchaseAmount: _maxPurchaseAmount,
            saleName: _saleName,
            isFinalized: false
        });
        emit NewSaleCreated(
            saleCount,
            _startTime,
            _endTime,
            _hardCap,
            _tokenPriceUSD,
            _saleName,
            _minPurchaseAmount,
            _maxPurchaseAmount
        );
    }

    function calculateTokenAmount(
        PaymentMethod paymentMethod,
        uint256 paymentAmount
    ) public view returns (uint256) {
        int256 price = _getPriceFeed(paymentMethod) * int256(PRECISION_10);
        require(price > 0, "Invalid price feed");

        uint256 currentSaleId = getCurrentSaleId();
        Sale storage sale = sales[currentSaleId];

        uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Token price in (18 decimals)

        uint256 paymentAmountInUSD;

        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmountInUSD =
                (uint256(price) * paymentAmount) /
                uint256(PRECISION_18);
        }
        // else if (paymentMethod == PaymentMethod.USDC || paymentMethod == PaymentMethod.USDT) {
        // uint256 stablecoinDecimals = 6;
        // uint256 normalizedAmount = paymentAmount * (10**(18 - stablecoinDecimals));
        // paymentAmountInUSD = (uint256(price) * normalizedAmount) / uint256(PRECISION_18);
        // }
        else {
            revert("Unsupported payment method");
        }

        uint256 tokenAmount = (paymentAmountInUSD * uint256(PRECISION_18)) /
            tokenPriceInUSD;
        return tokenAmount;
    }

    function calculatePaymentAmount(
        PaymentMethod paymentMethod,
        uint256 tokenAmount
    ) public view returns (uint256) {
        require(tokenAmount > 0, "Token amount must be greater than zero");

        int256 price = _getPriceFeed(paymentMethod) * int256(PRECISION_10); // Price is now 18 decimals
        require(price > 0, "Invalid price feed");

        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");

        Sale storage sale = sales[currentSaleId];
        uint256 tokenPriceInUSD = sale.tokenPriceUSD; // Assumes token price is in 18 decimals
        uint256 totalPaymentInUSD = (tokenAmount * tokenPriceInUSD) /
            PRECISION_18;

        uint256 paymentAmount;
        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmount = (totalPaymentInUSD * PRECISION_18) / uint256(price);
        }
        // else if (paymentMethod == PaymentMethod.USDT || paymentMethod == PaymentMethod.USDC) {
        //     paymentAmount = (totalPaymentInUSD * (10 ** 6)) / uint256(price);
        // }
        else {
            revert("Unsupported payment method");
        }
        return paymentAmount;
    }

    function buyTokens(PaymentMethod paymentMethod, uint256 paymentAmount)
        external
        payable
        icoNotFinalized
    {
        require(msg.sender != owner(), "Owner cannot buy tokens");
        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");

        Sale storage sale = sales[currentSaleId];
        require(!sale.isFinalized, "Sale already finalized");

        // Check whitelist for restricted sales
        if (
            keccak256(abi.encodePacked(sale.name)) ==
            keccak256("Venture Capital") ||
            keccak256(abi.encodePacked(sale.name)) ==
            keccak256("Private Sale A") ||
            keccak256(abi.encodePacked(sale.name)) ==
            keccak256("Private Sale B")
        ) {
            require(
                whitelistedUsers[msg.sender],
                "Only whitelisted users allowed"
            );
        }
        require(
            paymenAmount >= sale.minPurchaseAmount,
            "Below minimum purchase amount"
        );
        require(
            paymenAmount <= sale.maxPurchaseAmount,
            "Exceeds maximum purchase limit"
        );

        // Ensure valid BNB payment
        uint256 tokenAmount;
        if (paymentMethod == PaymentMethod.BNB) {
            // Handle native currency payments (BNB)
            require(msg.value > 0, "Send a valid BNB amount");
            tokenAmount = calculateTokenAmount(paymentMethod, msg.value);
            investorPayments[msg.sender][paymentMethod] += msg.value;
        }
        // else if (
        //     paymentMethod == PaymentMethod.USDT ||
        //     paymentMethod == PaymentMethod.USDC
        // ) {
        //     // Handle stablecoin payments
        //     require(paymentAmount > 0, "Enter a valid stablecoin amount");
        //     IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
        //         ? IERC20(usdt)
        //         : IERC20(usdc);
        //     require(stablecoin.transferFrom(msg.sender,address(this),paymentAmount),"Stablecoin transfer failed");
        //     // Calculate token amount for stablecoin payment
        //     tokenAmount = calculateTokenAmount(paymentMethod, paymentAmount);
        //     investorPayments[msg.sender][paymentMethod] += paymentAmount;
        // }
        else {
            revert("Unsupported payment method");
        }
        require(tokenAmount > 0, "Invalid token amount");
        // Ensure the purchase does not exceed the hard cap
        uint256 totalCostInUSD = (tokenAmount * sale.tokenPriceUSD) /
            PRECISION_18;
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

        initialRelease = (tokenAmount * 10) / 100; // 10% initial release
        console.log(initialRelease, "===initialRelease");
        lockedTokens = tokenAmount - initialRelease;
        // Set lockup: 6-month lockup
        require(
            token.setLockup(
                msg.sender,
                block.timestamp + 0.5 years,
                initialRelease
            ),
            "Lockup failed"
        );
        // token.setLockup(msg.sender,0.5 years,initialRelease);
        require(
            token.transfer(msg.sender, initialRelease),
            "Token transfer failed"
        ); // transfer initial 10% to investor
        require(
            token.transfer(address(vestingContract), lockedTokens),
            "Token transfer to vesting contract failed"
        );

        // Set 90% of tokens with 12-month vesting
        vestingContract.registerVesting(
            msg.sender,
            currentSaleId,
            tokenAmount, //totaltokens
            initialRelease, // claimedtokens
            lockedTokens, //locked tokens
            block.timestamp, // currenttime
            0.5 years, // lockup period
            1 years, // vesting period
            30 days // interval period
        );
    }

    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(uint256 saleId, bool _allow)
        public
        onlyOwner
    {
        allowImmediateFinalization = _allow;
        Sale storage sale = sales[saleId];
        sale.endTime = block.timestamp;
        if (block.timestamp <= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
        emit ImmediateFinalization(saleId);
    }

    function finalizeICO() public nonReentrant onlyOwner icoNotFinalized {
        require(
            totalFundsRaisedUSD >= softCapInUSD ||
                totalFundsRaisedUSD >= hardCapInUSD ||
                block.timestamp >= getLatestSaleEndTime(),
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
        else if (
            totalFundsRaisedUSD >= softCapInUSD && allowImmediateFinalization
        ) {
            isICOFinalized = true;
            _transferFundsToOwner();
            emit ICOFinalized(totalTokensSold);
        }
        // If the soft cap is reached and all sales are completed, finalize the ICO.
        else {
            require(
                block.timestamp >= getLatestSaleEndTime(),
                "Sale is still ongoing"
            );
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

        // // Transfer stablecoin funds (USDT/USDC)
        // uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
        // if (usdtBalance > 0) {
        //     require(IERC20(usdt).transfer(owner(), usdtBalance), "USDT transfer failed");
        // }

        // uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        // if (usdcBalance > 0) {
        //     require(IERC20(usdc).transfer(owner(), usdcBalance), "USDC transfer failed");
        // }
    }

    function claimRefund() external nonReentrant icoNotFinalized {
        require(
            block.timestamp > getLatestSaleEndTime() ||
                allowImmediateFinalization,
            "Sale ongoing"
        );
        require(totalFundsRaisedUSD < softCapInUSD, "Soft cap reached");

        uint256 totalRefund = 0;

        // Refund contributions for all payment methods
        for (uint8 j = 0; j < 4; j++) {
            PaymentMethod paymentMethod = PaymentMethod(j);
            uint256 amount = investorPayments[msg.sender][paymentMethod];

            if (amount > 0) {
                investorPayments[msg.sender][paymentMethod] = 0; // Reset the payment record
                totalRefund += amount;

                if (paymentMethod == PaymentMethod.BNB) {
                    // Refund in native currency (BNB)
                    (bool sent, ) = payable(msg.sender).call{value: amount}("");
                    require(sent, "BNB refund failed");
                }
                // Uncomment for stablecoin refunds
                // else if (paymentMethod == PaymentMethod.USDT || paymentMethod == PaymentMethod.USDC) {
                //     IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
                //         ? IERC20(usdt)
                //         : IERC20(usdc);
                //     require(
                //         stablecoin.transfer(msg.sender, amount),
                //         "Stablecoin refund failed"
                //     );
                // }
                else {
                    revert("Unsupported payment method for refund");
                }

                emit RefundInitiated(msg.sender, amount, paymentMethod);
            }
        }

        require(totalRefund > 0, "No funds to refund");
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

    // function getSoftCapReached() public view returns (bool) {
    //     return (totalFundsRaisedUSD >= softCapInUSD);
    // }

    function getHardCapReached() public view returns (bool) {
        return (totalFundsRaisedUSD >= hardCapInUSD);
    }

    function getInvestorCount() public view returns (uint256 investorCount) {
        investorCount = investors.length;
        return investorCount;
    }
}
