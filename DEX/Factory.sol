// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol";
import "hardhat/console.sol";

contract factory {
    mapping(erc20token => mapping(erc20token => pool)) public getPair;
    pool[] public allPairs;
    event PairCreated(
        erc20token indexed token0,
        erc20token indexed token1,
        pool pair,
        uint256
    );

    event syncReserves(pool pair, uint256 reserve0, uint256 reserve1);
    event liquidityAdded(
        pool pair,
        erc20token token0,
        erc20token token1,
        uint256 quant0,
        uint256 quant1
    );
    event liquidityRemoved(
        pool pair,
        erc20token token0,
        erc20token token1,
        uint256 quant0,
        uint256 quant1
    );
    event Swap(
        pool pair,
        erc20token tokenIN,
        erc20token tokenOUT,
        uint256 quantIN,
        uint256 quantOUT
    );

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(erc20token tokenA, erc20token tokenB)
        public
        returns (pool Pair)
    {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");

        (erc20token token0, erc20token token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(
            token0 != erc20token(address(0)) &&
            token1 != erc20token(address(0)),
            "ZERO_ADDRESS"
        );
        require(getPair[token0][token1] == pool(address(0)), "PAIR_EXISTS");

        pool pair = new pool(tokenA, tokenB, factory(address(this)));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
        return pair;
    }

    function addLiquidity(
        erc20token tokenA,
        erc20token tokenB,
        uint256 _amount0,
        uint256 _amount1
    ) public returns (string memory) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        pool addr;
        require(
            tokenA != erc20token(address(0)) &&
            tokenB != erc20token(address(0)),
            "ZERO_ADDRESS"
        );
        if (getPair[tokenA][tokenB] == pool(address(0))) {
            addr = createPair(tokenA, tokenB);
        } else {
            addr = getPair[tokenA][tokenB];
        }
        pool pair = pool(addr);
        uint256 _reserve0 = pair.reserveToken0();
        uint256 _reserve1 = pair.reserveToken1();

        if (_reserve0 != 0 && _reserve1 != 0) {
            require(
                (_reserve0 > _reserve1 && _amount1 > _amount0) ||
                    (_reserve1 > _reserve0 && _amount0 > _amount1),
                "reserves are not in sync"
            );
            uint256 ratio0 = (_reserve0 * 10000) / _reserve1;
            uint256 ratio1 = (_reserve1 * 10000) / _reserve0;
            console.log(ratio1);
            console.log(ratio0);
            uint256 ratio = ratio0 <= ratio1 ? ratio1 : ratio0;
            console.log(ratio);
            require(
                (_amount0 * 10**4) / _amount1 == ratio ||
                    (_amount1 * 10**4) / _amount0 == ratio,
                "liquidity needed to be in ratio according existing ones"
            );
        }
        address caller = msg.sender;
        require(
            tokenA.balanceOf(caller) > _amount0 &&
            tokenB.balanceOf(caller) > _amount1,
            "not enough balance"
        );
        Vault _lp = pair.LP();

        tokenA.approve(caller, address(_lp), _amount0);
        tokenB.approve(caller, address(_lp), _amount1);
        _lp.deposit(_amount0, _amount1, caller);

        pair.updateAfterLiquidity(_amount0, _amount1);
        emit syncReserves(pair, pair.reserveToken0(), pair.reserveToken1());
        emit liquidityAdded(pair, tokenA, tokenB, _amount0, _amount1);
        return ("add liquidity as this pair");
    }

    function AmountOut(
        erc20token tokenOUT,
        uint256 amountIN,
        erc20token tokenIN
    ) internal view returns (uint256 amountOUT, pool addr) {
        require(tokenIN != tokenOUT, "IDENTICAL_ADDRESSES");
        (erc20token token0, erc20token token1) = tokenIN < tokenOUT
            ? (tokenIN, tokenOUT)
            : (tokenOUT, tokenIN);
        require(
            token0 != erc20token(address(0)) &&
                token1 != erc20token(address(0)),
            "ZERO_ADDRESS"
        );
        require(
            getPair[token0][token1] != pool(address(0)),
            "create pair firstly"
        );
        addr = getPair[token0][token1];
        pool pair = pool(addr);
        uint256 _reserve0 = pair.reserveToken0();
        uint256 _reserve1 = pair.reserveToken1();
        uint256 Kconst = _reserve0 * _reserve1;

        if (tokenIN == token0) {
            uint256 reserve = _reserve0 + amountIN;
            uint256 out = _reserve1 - (Kconst / reserve);
            return (out, addr);
        } else {
            uint256 reserve = _reserve1 + amountIN;
            uint256 out = _reserve0 - (Kconst / reserve);
            return (out, addr);
        }
    }

    function swap(
        erc20token tokenOUT,
        uint256 amountIN,
        erc20token tokenIN
    ) public returns (string memory) {
        address caller = msg.sender;
        require(tokenIN.balanceOf(caller) > amountIN, "not enough balance");
        uint256 AmountOUT;
        pool pair;
        (AmountOUT, pair) = AmountOut(tokenOUT, amountIN, tokenIN);
        erc20token token0 = pair.token0();
        Vault _lp = pair.LP();
        tokenIN.approve(caller, address(this), amountIN);
        tokenIN.transferFrom(caller, address(_lp), amountIN);
        tokenOUT.approve(address(_lp), address(this), AmountOUT);
        tokenOUT.transferFrom(address(_lp), caller, AmountOUT);
        if (token0 == tokenIN) {
            pair.updateAfterSwap(amountIN, AmountOUT, true);
        } else {
            pair.updateAfterSwap(AmountOUT, amountIN, false);
        }
        emit syncReserves(pair, pair.reserveToken0(), pair.reserveToken1());
        emit Swap(pair, tokenIN, tokenOUT, amountIN, AmountOUT);
        return "swaping successful";
    }

    function RemoveLiquidity(
        erc20token tokenA,
        erc20token tokenB,
        uint256 _LPtoken
    ) public returns (string memory) {
        address caller = msg.sender;
        (erc20token token0, erc20token token1, uint256 LPtoken) = tokenA <
            tokenB
            ? (tokenA, tokenB, _LPtoken)
            : (tokenB, tokenA, _LPtoken);
        require(
            getPair[token0][token1] != pool(address(0)),
            "create pair firstly"
        );
        pool addr = getPair[token0][token1];
        pool pair = pool(addr);
        Vault _lpToken = pair.LP();
        require(
            _lpToken.balanceOf(caller) >= LPtoken,
            "not added sufficient liquidity"
        );
        (uint256 amountToken0, uint256 amountToken1) = _lpToken.withdraw(
            LPtoken,
            caller
        );

        pair.updateAfterRemoveLiquidity(amountToken0, amountToken1);
        emit syncReserves(pair, pair.reserveToken0(), pair.reserveToken1());
        emit liquidityAdded(pair, token0, token1, amountToken0, amountToken1);
        return "removed liquidity";
    }
}
