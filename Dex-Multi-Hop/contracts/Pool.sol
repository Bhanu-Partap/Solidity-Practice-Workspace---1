// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Factory.sol";
import "./libraries/Math.sol";

contract pool is ERC20 {
    address public _factory;
    address public token0;
    address public token1;

    uint256 public reserveToken0; //for small token in size
    uint256 public reserveToken1;

    uint256 private blockTimestampLast;

    constructor(
        address _token0,
        address _token1,
        address _fac
    ) ERC20("Liquidity Provider Token", "LP-TKN") {
        require(msg.sender == address(_fac), "FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
        _factory = _fac;
    }

    function approveforliquidity(uint256 amount0, uint256 amount1) external {
        require(msg.sender == address(_factory), "forbidden");
        ERC20(token0).approve(_factory, amount0);
        ERC20(token1).approve(_factory, amount1);
    }

    function approveforswap(address tokenOUT, uint256 amount) external {
        require(msg.sender == _factory, "forbidden");
        ERC20(tokenOUT).approve(address(_factory), amount);
    }

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "DEX: LOCKED");
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

    function deposit(
        uint256 amount0,
        uint256 amount1,
        address sender
    ) public {
        require(msg.sender == _factory, "forbidden");
        require(amount0 > 0 && amount1 > 0, "nedd to add liq");
        uint256 amountLP = Math.sqrt(amount0 * amount1);

        _mint(sender, amountLP);
    }

    function withdraw(uint256 amount, address sender)
        external
        returns (uint256, uint256)
    {
        require(amount > 0);
        require(msg.sender == _factory, "forbidden");

        uint256 supplyLPToken = totalSupply();
        uint256 percentageLiq = (amount * 100) / supplyLPToken;

        uint256 reserve0 = reserveToken0;
        uint256 reserve1 = reserveToken1;
        uint256 amount0 = (reserve0 * percentageLiq) / 100;
        uint256 amount1 = (reserve1 * percentageLiq) / 100;

        _burn(sender, amount);

        return (amount0, amount1);
    }

    function updateAfterSwap(
        address tokenIn,
        uint256 amountIN,
        uint256 amountOUT
    ) external {
        require(msg.sender == _factory, "forbidden");
        if (tokenIn == token0) {
            reserveToken0 += amountIN;
            reserveToken1 -= amountOUT;
            blockTimestampLast = block.timestamp;
        } else {
            reserveToken0 -= amountIN;
            reserveToken1 += amountOUT;
            blockTimestampLast = block.timestamp;
        }
    }

    function updateAfterLiquidity(
        address tokenA,
        uint256 amount0,
        uint256 amount1
    ) external {
        require(msg.sender == address(_factory), "forbidden");
        if (tokenA == token0) {
            reserveToken0 += amount0;
            reserveToken1 += amount1;
        } else {
            reserveToken0 += amount1;
            reserveToken1 += amount0;
        }
        blockTimestampLast = block.timestamp;
    }

    function updateAfterRemoveLiquidity(
        address tokenA,
        uint256 amount0,
        uint256 amount1
    ) external {
        require(msg.sender == _factory, "forbidden");
        if (tokenA == token0) {
            reserveToken0 -= amount0;
            reserveToken1 -= amount1;
            blockTimestampLast = block.timestamp;
        } else {
            reserveToken0 -= amount1;
            reserveToken1 -= amount0;
            blockTimestampLast = block.timestamp;
        }
    }

    // function approveTokens(
    //     address token,
    //     address spender,
    //     uint256 amount
    // ) external {
    //     require(msg.sender == _factory, "forbidden");

    //     ERC20(token).approve(spender, amount);
    // }
}
