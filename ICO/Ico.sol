// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "./IdentityFactory.sol";

contract ICO is Ownable {

    //struct
    struct Sale {
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 tokensSold;
        bool isFinalized;
    }

    //state variable
    // IDfactory public ID_FactoryAddress;
    IERC20 public token;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public saleCount;
    uint256 public totalTokensSold;
    address[] public investors;
    bool public isICOFinalized = false;
    bool public isTokensAirdropped=false;
    bool public allowImmediateFinalization = false; 

    //mapping
    mapping(uint256 => Sale) public sales;
    // mapping(address => bool) public whitelisted;
    mapping(address => uint256) public contributions;            //  tracks the amount of ETH paid by investor
    mapping(address => uint256) public tokensBoughtByInvestor;  //  tracks the amount of tokens bought by investors 

    // events
    // event Whitelisted(address indexed account);
    event ICOFinalized(uint256 totalTokensSold);
    event RefundInitiated(address indexed investor, uint256 amount);
    event TokensPurchased(address indexed buyer, uint256 saleId, uint256 amount);
    event NewSaleCreated(uint256 saleId, uint256 startTime, uint256 endTime, uint256 tokenPrice);

    constructor(IERC20 _token, uint256 _softCap, uint256 _hardCap) Ownable(msg.sender) {
        token = _token;
        softCap = _softCap;
        hardCap = _hardCap;
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
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

    function createSale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenPrice
    ) external onlyOwner icoNotFinalized {
        require(_startTime>block.timestamp,"Start time must be greater than current time");
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
    
    // if using whitelisting mechanism then add isWhitelisted modifier in buy token duntion
    function buyTokens() external payable icoNotFinalized  {
        require(msg.sender!= owner(),"Its only for Investors - You can't buy your own token");
        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");
        require(msg.value >0,"Enter the valid amount");
        
        // finalizing previous sales
        for(uint256 i =1;i<=saleCount;i++){
        finalizeSaleIfEnded(i);
        }

        Sale storage sale = sales[currentSaleId];
        require(!sale.isFinalized, "Sale already finalized");

        uint256 tokenPrice = sale.tokenPrice;
        require(msg.value % tokenPrice == 0, "Amount must be equal or multiple of the token price");

        uint256 tokensToBuy = (msg.value) / sale.tokenPrice;
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

    function finalizeSaleIfEnded(uint256 saleId) internal {
    Sale storage sale = sales[saleId];

    if (block.timestamp >= sale.endTime && !sale.isFinalized) {
        sale.isFinalized = true;
    }
    }

    // Owner decides whether immediate finalization is allowed
    function setAllowImmediateFinalization(bool _allow) external onlyOwner {
        allowImmediateFinalization = _allow; 
    }

    // function finalizeICO() public onlyOwner icoNotFinalized {
    //     require(
    //     totalTokensSold >= softCap && totalTokensSold <=hardCap || block.timestamp >= getLatestSaleEndTime(),
    //     "Cannot finalize: Soft cap not reached or sale is ongoing"
    // );

    // // if owner wants to finalize the ico just after reching the soft cap
    // if (allowImmediateFinalization && totalTokensSold >= softCap) {
    //     isICOFinalized = true;

    //     payable(owner()).transfer(address(this).balance);
    //     emit ICOFinalized(totalTokensSold);
    // }
    // // owner wants to finalize the ico after the sales end and soft cap already reached 
    //  else {
    //     require(block.timestamp >= getLatestSaleEndTime() || totalTokensSold == hardCap, "Cannot finalize: Sale not ended or hard cap not reached");
    //     isICOFinalized = true;
    //     payable(owner()).transfer(address(this).balance);
    //     emit ICOFinalized(totalTokensSold);
    // }
    // }

    function finalizeICO() public onlyOwner icoNotFinalized {
    //Check if the hard cap has been reached or the soft cap is reached and sale is ongoing.
    require(
        totalTokensSold >= softCap || totalTokensSold >= hardCap || block.timestamp >= getLatestSaleEndTime(),
        "Cannot finalize: Soft cap not reached or sale is ongoing"
    );

    for (uint256 i = 1; i <= saleCount; i++) {
        Sale storage sale = sales[i];
        if (block.timestamp >= sale.endTime && !sale.isFinalized) {
            sale.isFinalized = true;
        }
    }
// 10000000000000000
// 930000000000000000
    //If the hard cap has been reached, finalize immediately.
    if (totalTokensSold >= hardCap) {
        isICOFinalized = true;
        payable(owner()).transfer(address(this).balance);
        emit ICOFinalized(totalTokensSold);
    }
    //If the soft cap is reached but sale is not ended, the owner can finalize immediately if allowed.
    else if (totalTokensSold >= softCap && allowImmediateFinalization) {
        isICOFinalized = true;
        payable(owner()).transfer(address(this).balance);
        emit ICOFinalized(totalTokensSold);
    }
    //If the soft cap is reached and all sales are completed (sale ended), finalize the ICO.
    else {
        require(block.timestamp >= getLatestSaleEndTime(), "Sale is still ongoing");
        isICOFinalized = true;
        payable(owner()).transfer(address(this).balance);
        emit ICOFinalized(totalTokensSold);
    }
}

    function initiateRefund() external onlyOwner icoNotFinalized {
        require(block.timestamp > getLatestSaleEndTime(), "ICO ongoing");
        require(totalTokensSold < softCap, "Soft cap reached");

        for(uint256 i = 0; i < investors.length; i++) {
        address investor = investors[i];
        uint256 amount = contributions[investor];

        if (amount > 0) {
            contributions[investor] = 0; // resetting the mapping before the transfer (reentrancy)
            payable(investor).transfer(amount); 
            emit RefundInitiated(investor, amount);
        }
        isICOFinalized = true;
    }
}

    function airdropTokens() external onlyOwner {
        require(!isTokensAirdropped, "Airdrop already completed");
        require(isICOFinalized, "ICO not finalized");

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 tokensBought = tokensBoughtByInvestor[investor];
            if (tokensBought > 0) {
                bool success = token.transferFrom(owner(), investor, tokensBought);
                require(success, "Token transfer failed");
            }
        }
        isTokensAirdropped=true;
    }

    // Getter Functions
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

    function getSaleStartEndTime(uint256 _saleId) public view returns(uint256 _startTime, uint256 _endTime){
        Sale memory sale = sales[_saleId];
        return ( sale.startTime, sale.endTime);
    }

    function getSoftCapReached() public view onlyOwner returns(bool){
        return (totalTokensSold >= softCap);
    }

    function getHardCapReached() public view onlyOwner returns(bool){
        return (totalTokensSold  == hardCap);
    }

}
