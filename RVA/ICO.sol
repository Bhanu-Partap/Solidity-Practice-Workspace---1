// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./Vesting.sol";
import "./UpgradableToken.sol";
import "./IdentityFactory.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ICO is Ownable, ReentrancyGuard,Pausable {
    using SafeMath for uint256;

    // Chainlink Price Feeds
    AggregatorV3Interface public priceFeedBNB;
    AggregatorV3Interface public priceFeedUSDT;
    AggregatorV3Interface public priceFeedUSDC;

    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        uint256 hardCap;
        uint256 tokenPrice; //(USD)
        uint256 tokensSold;
        uint256 fundRaised;
        uint256 minPurchaseAmount;
        uint256 maxPurchaseAmount;
        address[] investors;
        string name;
        bool isPrivate;
        bool isFinalized;
        bool immediateFinalizeSale;
    }

    enum PaymentMethod {
        BNB,
        USDT,
        USDC
    }

    // State variables
    ERC20Token public token;
    IDfactory public IdentityContract;
    TokenVesting public vestingContract;
    uint256 public saleCount;
    uint256 public totalFundsRaisedUSD;
    uint256 public totalTokensSold;
    uint256 constant PRECISION_10 = 1e10;
    uint256 constant PRECISION_18 = 1e18;
    bool public isICOFinalized = false;
    // bool public allowImmediateFinalization = false;
    // address[] public investors;
    address public immutable usdt;
    address public immutable usdc;

    // Mappings
    mapping(uint256 => Sale) public sales;
    mapping(address => bool) public whitelistedUsers;
    mapping(address => bool) public blacklistedUsers;
    mapping(address => uint256) public contributionsInUSD;
    mapping(address => uint256) public tokensBoughtByInvestor;
    mapping(address => AggregatorV3Interface) private priceFeeds;
    // mapping(address => mapping(PaymentMethod => uint256))
    //     public investorPayments;
    mapping(uint256 => mapping(address => mapping(PaymentMethod => uint256)))
        public investorPayments;
    mapping(uint256 => mapping(address => uint256))
        public tokensBoughtByInvestorForSale;
    mapping(address => PaymentMethod) public paymentMethodForInvestor;

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
    event RefundClaimed(
        address indexed investor,
        uint256 saleId,
        uint256 amount,
        PaymentMethod paymentMethod
    );
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
        address _usdt,
        address _usdc,
        address _priceFeedBNB,
        address _priceFeedUSDT,
        address _priceFeedUSDC
    ) Ownable(msg.sender) {
        token = _token;
        vestingContract = _vestingContract;
        IdentityContract = _identityContract;
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

    modifier isWhitelisted() {
        require(whitelistedUsers[msg.sender], "Not a whitelisted user");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function whitelistUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        if (blacklistedUsers[_user]) {
            blacklistedUsers[_user] = false;
        }
        whitelistedUsers[_user] = true;
        emit Whitelisted(_user);
    }

    function blacklistUser(address _user) external onlyOwner {
        require(_user != address(0), "Invalid address");
        if (whitelistedUsers[_user]) {
            whitelistedUsers[_user] = false;
        }
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
        address[] memory _investors,
        string memory _saleName,
        bool _isPrivate
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
        require(
            _softCap <= _hardCap,
            "Soft cap must be less than or equal to hard cap"
        );
        require(bytes(_saleName).length > 0, "Sale name cannot be empty");

        saleCount++;

        // Create a new sale entry
        sales[saleCount] = Sale({
            startTime: _startTime,
            endTime: _endTime,
            softCap: _softCap,
            hardCap: _hardCap,
            tokenPrice: _tokenPriceUSD,
            tokensSold: 0,
            fundRaised: 0,
            minPurchaseAmount: _minPurchaseAmount,
            maxPurchaseAmount: _maxPurchaseAmount,
            investors: _investors,
            name: _saleName,
            isPrivate: _isPrivate,
            isFinalized: false,
            immediateFinalizeSale: false
        });

        emit NewSaleCreated(
            saleCount,
            _startTime,
            _endTime,
            _softCap,
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

        uint256 tokenPriceInUSD = sale.tokenPrice; // Token price in (18 decimals)

        uint256 paymentAmountInUSD;

        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmountInUSD =
                (uint256(price) * paymentAmount) /
                uint256(PRECISION_18);
        } else if (
            paymentMethod == PaymentMethod.USDC ||
            paymentMethod == PaymentMethod.USDT
        ) {
            uint256 stablecoinDecimals = 6;
            uint256 normalizedAmount = paymentAmount *
                (10**(18 - stablecoinDecimals));
            paymentAmountInUSD =
                (uint256(price) * normalizedAmount) /
                uint256(PRECISION_18);
        } else {
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
        uint256 tokenPriceInUSD = sale.tokenPrice; // Assumes token price is in 18 decimals
        uint256 totalPaymentInUSD = (tokenAmount * tokenPriceInUSD) /
            PRECISION_18;

        uint256 paymentAmount;
        if (paymentMethod == PaymentMethod.BNB) {
            paymentAmount = (totalPaymentInUSD * PRECISION_18) / uint256(price);
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
        whenNotPaused
        icoNotFinalized
    {
        require(!blacklistedUsers[msg.sender], "Blacklisted");
        require(msg.sender != owner(), "Owner restricted");
        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");

        Sale storage sale = sales[currentSaleId];
        require(!sale.isFinalized, "Sale finalized");

        isRestrictedSale(currentSaleId, msg.sender);
        uint256 userTotalPurchase = tokensBoughtByInvestorForSale[
            currentSaleId
        ][msg.sender] + paymentAmount;

        // min max purchse restriciton
        require(
            paymentAmount >= sale.minPurchaseAmount &&
                paymentAmount <= sale.maxPurchaseAmount &&
                userTotalPurchase <= sale.maxPurchaseAmount,
            "Invalid purchase amount"
        );

        uint256 tokenAmount = processPayment(
            paymentMethod,
            paymentAmount,
            currentSaleId
        );
        require(tokenAmount > 0, "Invalid token amount");

        // Ensure hard cap is not exceeded
        uint256 totalCostInUSD = (tokenAmount * sale.tokenPrice) / PRECISION_18;
        require(
            sale.fundRaised + totalCostInUSD <= sale.hardCap,
            "Hard cap reached"
        );

        // Update state
        updateInvestorData(
            msg.sender,
            currentSaleId,
            tokenAmount,
            totalCostInUSD
        );

        // Lockup and vesting
        distributeTokens(msg.sender, currentSaleId, tokenAmount);

        emit TokensPurchased(
            msg.sender,
            currentSaleId,
            tokenAmount,
            sale.tokenPrice,
            msg.value,
            paymentMethod
        );
    }

    function isRestrictedSale(uint256 saleId, address _investor)
        internal
        view
        returns (bool)
    {
        require(saleId > 0 && saleId <= saleCount, "Invalid sale ID");
        Sale storage sale = sales[saleId];

        if (!sale.isPrivate) {
            return IdentityContract.hasIdentity(_investor);
        }
        return whitelistedUsers[_investor];
    }

    function processPayment(
        PaymentMethod paymentMethod,
        uint256 paymentAmount,
        uint256 saleId
    ) internal returns (uint256) {
        if (paymentMethod == PaymentMethod.BNB) {
            require(msg.value > 0, "Invalid BNB");
            uint256 tokenAmount = calculateTokenAmount(
                paymentMethod,
                msg.value
            );
            investorPayments[saleId][msg.sender][PaymentMethod.BNB] += msg
                .value;
            return tokenAmount;
        } else if (
            paymentMethod == PaymentMethod.USDT ||
            paymentMethod == PaymentMethod.USDC
        ) {
            require(paymentAmount > 0, "Invalid stablecoin");
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
            uint256 tokenAmount = calculateTokenAmount(
                paymentMethod,
                paymentAmount
            );
            investorPayments[saleId][msg.sender][
                paymentMethod
            ] += paymentAmount;
            return tokenAmount;
        }
        revert("Unsupported payment");
    }

    function updateInvestorData(
        address investor,
        uint256 saleId,
        uint256 tokenAmount,
        uint256 totalCostInUSD
    ) internal {
        Sale storage sale = sales[saleId];
        contributionsInUSD[investor] += totalCostInUSD; // for overall contribution

        sale.fundRaised += totalCostInUSD; // updating the fund specific to sale
        totalFundsRaisedUSD += totalCostInUSD;
        sale.tokensSold += tokenAmount;
        totalTokensSold += tokenAmount;
        tokensBoughtByInvestorForSale[saleId][investor] += tokenAmount;

        if (tokensBoughtByInvestor[investor] == 0) {
            sale.investors.push(investor);
        }
        tokensBoughtByInvestor[investor] += tokenAmount;
    }

    function distributeTokens(
        address investor,
        uint256 saleId,
        uint256 tokenAmount
    ) internal {
        uint256 initialRelease = (tokenAmount * 10) / 100; // 10% initial release
        console.log("=====initialRelease====", initialRelease);
        uint256 lockedTokens = tokenAmount - initialRelease;
        console.log("=====lockedTokens====", lockedTokens);

        token.setLockup(
            investor,
            block.timestamp + (0.5 * 365 days),
            initialRelease
        );
        require(
            token.transfer(investor, initialRelease),
            "Initial transfer failed"
        );
        require(
            token.transfer(address(vestingContract), lockedTokens),
            "Vesting transfer failed"
        );

        vestingContract.registerVesting(
            investor,
            saleId,
            tokenAmount, // Total tokens
            initialRelease, // Claimed tokens
            lockedTokens, // Locked tokens
            block.timestamp, // Start time
            0.5 * 365 days, // Lockup period
            365 days, // Vesting period
            30 days // Interval
        );
    }

    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(uint256 saleId, bool _allow)
        public
        onlyOwner
    {
        Sale storage sale = sales[saleId];
        sale.immediateFinalizeSale = _allow;
        sale.endTime = block.timestamp;
        if (block.timestamp <= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
        emit ImmediateFinalization(saleId);
    }

    function finalizeICO(address payable withdrawalAddress)
        public
        nonReentrant
        onlyOwner
        whenNotPaused
        icoNotFinalized
    {
        bool allSalesHardCapReached = true;
        bool allSalesSoftCapReachedAndEnded = true;

        // Loop through all sales to evaluate their conditions
        uint256 _saleCount = saleCount;
        for (uint256 i = 1; i <= _saleCount; i++) {
            Sale storage sale = sales[i];

            // Check if the sale's hard cap is reached
            if (sale.fundRaised < sale.hardCap) {
                allSalesHardCapReached = false; // hard cap not reached
            }

            // Check if the sale's soft cap is reached and the sale has ended
            if (
                sale.fundRaised >= sale.softCap ||
                block.timestamp > sale.endTime
            ) {
                allSalesSoftCapReachedAndEnded = false; // Not all sales have met the soft cap and ended
            }

            // Finalize individual sales that are eligible
            if (block.timestamp >= sale.endTime && !sale.isFinalized) {
                sale.isFinalized = true; // Mark sale as finalized
            }
        }

        // Determine whether to finalize the ICO
        if (allSalesHardCapReached || allSalesSoftCapReachedAndEnded) {
            isICOFinalized = true;
            _transferFunds(withdrawalAddress);
            emit ICOFinalized(totalTokensSold);
        } else {
            revert("Cannot finalize");
        }
    }

    function _transferFunds(address payable withdrawalAddress) private {
        require(withdrawalAddress != address(0), "Invalid address");

        uint256 nativeBalance = address(this).balance;
        if (nativeBalance > 0) {
            (bool success, ) = withdrawalAddress.call{value: nativeBalance}("");
            require(success, "Transfer failed");
        }

        // Transfer stablecoin funds (USDT/USDC)
        uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
        if (usdtBalance > 0) {
            require(
                IERC20(usdt).transfer(withdrawalAddress, usdtBalance),
                "USDT transfer failed"
            );
        }

        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        if (usdcBalance > 0) {
            require(
                IERC20(usdc).transfer(withdrawalAddress, usdcBalance),
                "USDC transfer failed"
            );
        }
    }

    function claimRefund(uint256 saleId) external nonReentrant whenNotPaused {
        require(saleId > 0 && saleId <= saleCount, "Invalid sale ID");
        Sale storage sale = sales[saleId];

        // Ensure the sale has ended or immediate finalization is allowed
        require(
            block.timestamp > sale.endTime || sale.immediateFinalizeSale,
            "Sale ongoing"
        );
        // Ensure the soft cap for this specific sale was not reached
        require(
            sale.fundRaised < sale.softCap,
            "Soft cap reached for this sale"
        );

        uint256 totalRefund = 0;

        // Refund contributions for all payment methods specific to this sale
        for (uint8 j = 0; j < 3; j++) {
            PaymentMethod paymentMethod = PaymentMethod(j);
            uint256 amount = investorPayments[saleId][msg.sender][
                paymentMethod
            ];

            if (amount > 0) {
                investorPayments[saleId][msg.sender][paymentMethod] = 0;
                totalRefund += amount;

                if (paymentMethod == PaymentMethod.BNB) {
                    (bool sent, ) = payable(msg.sender).call{value: amount}("");
                    require(sent, "BNB refund failed");
                } else if (
                    paymentMethod == PaymentMethod.USDT ||
                    paymentMethod == PaymentMethod.USDC
                ) {
                    IERC20 stablecoin = paymentMethod == PaymentMethod.USDT
                        ? IERC20(usdt)
                        : IERC20(usdc);
                    require(
                        stablecoin.transfer(msg.sender, amount),
                        "Stablecoin refund failed"
                    );
                } else {
                    revert("Unsupported payment method for refund");
                }
                // Emit refund event for this sale
                emit RefundClaimed(msg.sender, saleId, amount, paymentMethod);
            }
        }

        require(totalRefund > 0, "No funds to refund for this sale");
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

    function getSoftCapReached(uint256 saleId) public view returns (bool) {
        require(saleId > 0 && saleId <= saleCount, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        return (sale.fundRaised >= sale.softCap);
    }

    function getHardCapReached(uint256 saleId) public view returns (bool) {
        require(saleId > 0 && saleId <= saleCount, "Invalid sale ID");
        Sale storage sale = sales[saleId];
        return (sale.fundRaised >= sale.hardCap);
    }

    function getInvestorCount(uint256 saleId)
        public
        view
        returns (uint256 saleInvestorCount, uint256 overallInvestorCount)
    {
        require(saleId > 0 && saleId <= saleCount, "Invalid sale ID");

        // Get the specific sale
        Sale storage sale = sales[saleId];

        // Return the specific sale's investor count
        saleInvestorCount = sale.investors.length;

        // Calculate the overall investor count by checking each sale
        overallInvestorCount = 0;
        uint256 countForSale = saleCount;
        for (uint256 i = 1; i <= countForSale; i++) {
            overallInvestorCount += sales[i].investors.length;
        }
    }
}
