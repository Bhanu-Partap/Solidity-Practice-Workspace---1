// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenPriceFetcher {
    AggregatorV3Interface internal bnbUsdPriceFeed;
    AggregatorV3Interface internal daiBnbPriceFeed;
    // AggregatorV3Interface internal usdcBnbPriceFeed;
    // AggregatorV3Interface internal usdtBnbPriceFeed;

    uint256 public tokenPriceInUSD; // Token price in USD (e.g., $0.5)

    constructor(
        address _bnbUsdPriceFeed,
        address _daiBnbPriceFeed,
        // address _usdcBnbPriceFeed,
        // address _usdtBnbPriceFeed,
        uint256 _tokenPriceInUSD // Price in USD with 18 decimals
    ) {
        bnbUsdPriceFeed = AggregatorV3Interface(_bnbUsdPriceFeed);
        daiBnbPriceFeed = AggregatorV3Interface(_daiBnbPriceFeed);
        // usdcBnbPriceFeed = AggregatorV3Interface(_usdcBnbPriceFeed);
        // usdtBnbPriceFeed = AggregatorV3Interface(_usdtBnbPriceFeed);
        tokenPriceInUSD = _tokenPriceInUSD; // Example: 0.5 * 10^18
    }

    // Fetch the latest BNB/USD price
    function getBnbUsdPrice() public view returns (uint256) {
        (, int256 price, , , ) = bnbUsdPriceFeed.latestRoundData();
        return uint256(price * 10**10); // Scale to 18 decimals
    }

    // Fetch the latest price for DAI/BNB
    function getDaiBnbPrice() public view returns (uint256) {
        (, int256 price, , , ) = daiBnbPriceFeed.latestRoundData();
        return uint256(price); // Already scaled to 18 decimals
    }

    // Fetch the latest price for USDC/BNB
    // function getUsdcBnbPrice() public view returns (uint256) {
    //     (, int256 price, , , ) = usdcBnbPriceFeed.latestRoundData();
    //     return uint256(price); // Already scaled to 18 decimals
    // }

    // Fetch the latest price for USDT/BNB
    // function getUsdtBnbPrice() public view returns (uint256) {
    //     (, int256 price, , , ) = usdtBnbPriceFeed.latestRoundData();
    //     return uint256(price); // Already scaled to 18 decimals
    // }

    // Calculate the token price in BNB for a given stablecoin
    function calculateTokenPriceInBNB(address stablecoin) public view returns (uint256) {
        uint256 bnbPriceInUSD = getBnbUsdPrice(); // BNB price in USD (18 decimals)
        uint256 stablecoinBnbPrice;

        if (stablecoin == address(daiBnbPriceFeed)) {
            stablecoinBnbPrice = getDaiBnbPrice();
        // } else if (stablecoin == address(usdcBnbPriceFeed)) {
        //     stablecoinBnbPrice = getUsdcBnbPrice();
        // } else if (stablecoin == address(usdtBnbPriceFeed)) {
        //     stablecoinBnbPrice = getUsdtBnbPrice();
        } else {
            revert("Unsupported stablecoin");
        }

        // Token price in BNB = (Token price in USD / BNB price in USD)
        uint256 tokenPriceInBNB = (tokenPriceInUSD * 1 ether) / bnbPriceInUSD;

        // Return token price in terms of the stablecoin's BNB price
        return (tokenPriceInBNB * 1 ether) / stablecoinBnbPrice;
    }
}
