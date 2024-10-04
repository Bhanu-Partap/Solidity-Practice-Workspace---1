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
    event syncReserve(address pool, uint256 reserve0, uint256 reserve1);

    constructor(
        address _token0,
        address _token1,
        address _fac,string memory name,string memory symbol
    ) ERC20(name, symbol) {
        require(msg.sender == address(_fac), "FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
        _factory = _fac;
    }

    function convertToTargetedPrecison(address token)
        internal
        view
        returns (uint256)
    {
        uint8 decimal = ERC20(token).decimals();
        uint8 addedPrecison = 18 - decimal;
        return 10**addedPrecison;
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
    ) external {
        require(msg.sender == _factory, "forbidden");
        require(amount0 > 0 && amount1 > 0, "nedd to add liq");
        uint256 amountLP = Math.sqrt(
            amount0 *
                amount1 *
                convertToTargetedPrecison(token0) *
                convertToTargetedPrecison(token1)
        );

        _mint(sender, amountLP);
    }

    function withdraw(uint256 amount, address sender)
        external
        returns (uint256, uint256)
    {
        require(amount > 0,"amount greater than zero");
        require(msg.sender == _factory, "forbidden");

        uint256 supplyLPToken = totalSupply();
        uint256 percentageLiq = (amount * 10**25) / supplyLPToken;

        uint256 reserve0 = reserveToken0;
        uint256 reserve1 = reserveToken1;
        uint256 amount0 = (reserve0 * percentageLiq) / 10**25;
        uint256 amount1 = (reserve1 * percentageLiq) / 10**25;

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
        require(reserveToken0 > 1 && reserveToken1 > 1, "not enough asset");
        emit syncReserve(address(this), reserveToken0, reserveToken1);
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
            emit syncReserve(address(this), reserveToken0, reserveToken1);
        } else {
            reserveToken0 += amount1;
            reserveToken1 += amount0;
        }
        blockTimestampLast = block.timestamp;
        emit syncReserve(address(this), reserveToken0, reserveToken1);
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
        require(reserveToken0 > 1 && reserveToken1 > 1, "not enough asset");
        emit syncReserve(address(this), reserveToken0, reserveToken1);
    }
}
