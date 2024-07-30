// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Token.sol";
import "./Pool.sol";

import "./libraries/Math.sol";
import "hardhat/console.sol";

contract Vault is ERC20 {
    pool public pair;

    constructor(pool _pair) ERC20("Liquidity Provider Token", "LP-TKN") {
        pair = _pair;
    }

    function deposit(
        uint256 amount0,
        uint256 amount1,
        address sender
    ) external {
        require(amount0 > 0 && amount1 > 0, "need some amount to add liq");
        uint256 amountLP = Math.sqrt(amount0 * amount1);
        erc20token token0 = pair.token0();
        erc20token token1 = pair.token1();

        _mint(sender, amountLP);
        token0.transferFrom(sender, address(this), amount0);
        token1.transferFrom(sender, address(this), amount1);
    }

    function withdraw(uint256 amount, address sender)
        external
        returns (uint256,uint256)
    {
        require(amount > 0);
        erc20token token0 = pair.token0();
        erc20token token1 = pair.token1();

        uint256 supplyLPToken = this.totalSupply();
        uint256 percentageLiq = (amount * 100) / supplyLPToken;

        uint reserve0= pair.reserveToken0();
        uint reserve1 = pair.reserveToken1();
        uint amount0 = (reserve0 * percentageLiq)/100;
        uint amount1 = (reserve1 * percentageLiq)/100;
        token0.transfer(sender, amount0);
        token1.transfer(sender, amount1);
        _burn(sender, amount);

        return (amount0,amount1);
    }

    function approve(
        address _owner,
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        address owner = _owner;
        _approve(owner, spender, amount);
        return true;
    }
}
