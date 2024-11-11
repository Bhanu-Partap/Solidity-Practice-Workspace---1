// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IdentityFactory.sol";

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
    IERC20 public token;
    IDfactory public ID_FactoryAddress;
    bool public isICOFinalized = false;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public saleCount;
    uint256 public totalTokensSold;
    address[] public investors;
    bool public allowImmediateFinalization = false; 

    //mapping
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256) public contributions;            //  tracks the amount of ETH paid by investor
    mapping(address => uint256) public tokensBoughtByInvestor;  //  tracks the amount of tokens bought by investors 

    // events
    event NewSaleCreated(uint256 saleId, uint256 startTime, uint256 endTime, uint256 tokenPrice);
    event TokensPurchased(address indexed buyer, uint256 saleId, uint256 amount);
    event ICOFinalized(uint256 totalTokensSold);
    event RefundInitiated(address indexed investor, uint256 amount);

    constructor(IERC20 _token, uint256 _softCap, uint256 _hardCap,address _IDFactoryAddress) Ownable(msg.sender) {
        token = _token;
        softCap = _softCap;
        hardCap = _hardCap;
        ID_FactoryAddress = IDfactory(_IDFactoryAddress);
    }

    modifier icoNotFinalized() {
        require(!isICOFinalized, "ICO already finalized");
        _;
    }

    function isVerifiedUser(address userWallet) public view returns (bool) {
        address verifiedUser = ID_FactoryAddress.getidentity(userWallet);
        return verifiedUser != address(0);
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
// 10000000000000000
    function buyTokens() external payable icoNotFinalized {
        require(msg.sender!= owner(),"Its only for Investors - You can't buy your own token");
        uint256 currentSaleId = getCurrentSaleId();
        require(currentSaleId != 0, "No active sale");
        require(msg.value >0,"Enter the valid amount");

        finalizeSaleIfEnded(currentSaleId);
        Sale storage sale = sales[currentSaleId];
        require(!sale.isFinalized, "Sale already finalized");

        uint256 tokenPrice = sale.tokenPrice;
        require(msg.value % tokenPrice == 0, "Amount must be equal to the token price ");

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

    function finalizeICO() public onlyOwner icoNotFinalized {
        require(
        totalTokensSold >= softCap && block.timestamp >= getLatestSaleEndTime(),
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
        require(isICOFinalized, "ICO not finalized");

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 tokensBought = tokensBoughtByInvestor[investor];
            if (tokensBought > 0) {
                bool success = token.transferFrom(owner(), investor, tokensBought);
                require(success, "Token transfer failed");
            }
        }
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
