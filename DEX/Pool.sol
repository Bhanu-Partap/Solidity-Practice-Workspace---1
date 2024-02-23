// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./LPtoken.sol";

// import {IERC20} from "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./Factory.sol";
import "./Token.sol";
import "./LPtoken.sol";

contract pool {
    factory public _factory;
    // bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    erc20token public token0;
    erc20token public token1;
    uint256 public supplyToken0;
    uint256 public supplyToken1;
    uint256 public reserveToken0;
    uint256 public reserveToken1;

    Vault public LP;

    uint256 ratio;

    constructor(
        erc20token _token0,
        erc20token _token1,
        factory _fac
    ) {
        require(msg.sender == address(_fac), "FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
        _factory = _fac;

        LP = new Vault(this);
    }

    // uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private blockTimestampLast;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves()
        public
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        )
    {
        _reserve0 = reserveToken0;
        _reserve1 = reserveToken1;
        _blockTimestampLast = blockTimestampLast;
    }

    function updateAfterLiquidity(uint256 amount0, uint256 amount1) external {
        require(msg.sender == address(_factory), "can't call this function");
        supplyToken0 += amount0;
        supplyToken1 += amount1;
        reserveToken0 += amount0;
        reserveToken1 += amount1;
        updateRatio();
        blockTimestampLast = block.timestamp;
    }

    function updateAfterRemoveLiquidity(uint256 amount0, uint256 amount1)
        external
    {
        require(msg.sender == address(_factory), "can't can this function");
        supplyToken0 -= amount0;

        supplyToken1 -= amount1;
        reserveToken0 -= amount0;
        reserveToken1 -= amount1;
        updateRatio();
        blockTimestampLast = block.timestamp;
    }

    function updateRatio() public returns (uint256 _ratio, string memory) {
        require(reserveToken0 != 0 && reserveToken1 != 0, "reserves are zero");
        uint256 reserve0 = (reserveToken0 * 10**4) / reserveToken1;
        uint256 reserve1 = (reserveToken1 * 10**4) / reserveToken0;
        console.log(reserve0);
        ratio = reserve0 <= reserve1 ? reserve1 : reserve0;
        console.log(ratio);
        return (ratio, "this ratio should be multipied by 1/10^18");
    }

    function updateAfterSwap(
        uint256 amount0,
        uint256 amount1,
        bool state
    ) external {
        if (state == true) {
            supplyToken0 += amount0;
            reserveToken0 += amount0;
            reserveToken1 -= amount1;
            blockTimestampLast = block.timestamp;
        } else {
            supplyToken1 += amount1; 
            reserveToken0 -= amount0;
            reserveToken1 += amount1;
            blockTimestampLast = block.timestamp;
        }
        updateRatio();
    }

    function updateRatio(uint256 _ratio) internal {
        ratio = _ratio;
    }

    function getratio() public view returns (uint256, string memory) {
        return (ratio, "this ratio should be multipied by 1/10^18");
    }
}
