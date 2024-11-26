// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ICO {
    AggregatorV3Interface internal usdcPriceFeed; // USDC/USD feed
    AggregatorV3Interface internal bnbPriceFeed;  // BNB/USD feed

    uint256 public tokenPriceUSD = 1 * 10**18; // 1 Token = $1, scaled to 18 decimals
    mapping(address => uint256) public tokenBalances; // Records purchased tokens

    constructor(address _usdcPriceFeed, address _bnbPriceFeed) {
        usdcPriceFeed = AggregatorV3Interface(_usdcPriceFeed);
        bnbPriceFeed = AggregatorV3Interface(_bnbPriceFeed);
    }

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price); // Convert to uint256
    }

    function buyTokensWithUSDC(uint256 usdcAmount) external {
        // Get USDC/USD price
        uint256 usdcPrice = getLatestPrice(usdcPriceFeed);
        uint256 tokenAmount = (usdcAmount * usdcPrice) / tokenPriceUSD;

        // Record token allocation
        tokenBalances[msg.sender] += tokenAmount;
    }

    function buyTokensWithBNB() external payable {
        // Get BNB/USD price
        uint256 bnbPrice = getLatestPrice(bnbPriceFeed);
        uint256 tokenAmount = (msg.value * bnbPrice) / tokenPriceUSD;

        // Record token allocation
        tokenBalances[msg.sender] += tokenAmount;
    }
}
