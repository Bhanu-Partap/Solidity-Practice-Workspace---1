// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Pool.sol";
import "hardhat/console.sol";

contract factory {
    mapping(address => mapping(address => address)) public getPair;
    pool[] public allPairs;
    uint256 constant DECIMALS = 18;
    event PairCreated(
        address indexed token0,
        address indexed token1,
        pool pair,
        uint256 pair_length
    );

    event liquidityAdded(
        pool pair,
        address token0,
        address token1,
        uint256 quant0,
        uint256 quant1,
        uint256 timestamp
    );
    event liquidityRemoved(
        pool pair,
        address token0,
        address token1,
        uint256 quant0,
        uint256 quant1,
        uint256 timestamp
    );

    event Swap(
        pool pair,
        address tokenIN,
        address tokenOUT,
        uint256 quantIN,
        uint256 quantOUT,
        uint256 timestamp
    );

    function convertToTargetedPrecison(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        uint8 decimal = ERC20(token).decimals();
        uint8 addedPrecison = 18 - decimal;
        return amount * (10**addedPrecison);
    }

    function convertToSourcePrecison(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        uint8 decimal = ERC20(token).decimals();
        uint8 addedPrecison = 18 - decimal;
        return amount / (10**addedPrecison);
    }

    function sortminTOmax(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        return (token0, token1);
    }

    function createPair(address tokenA, address tokenB)
        public
        returns (pool Pair)
    {
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(!ISpairExist(tokenA, tokenB), "PAIR_EXISTS");

        (address token0, address token1) = sortminTOmax(tokenA, tokenB);

        pool pair = new pool(token0, token1, address(this));
        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair); // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
        return pair;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function ISpairExist(address tokenA, address tokenB)
        public
        view
        returns (bool)
    {
        return getPair[tokenA][tokenB] != address(0);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 _amount0,
        uint256 _amount1
    ) public returns (string memory) {
        address caller = msg.sender;
        uint256 ratio;
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        pool pair;
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        if (!ISpairExist(tokenA, tokenB)) {
            pair = createPair(tokenA, tokenB);
            // ratio=1;
        } else {
            pair = pool(getPair[tokenA][tokenB]);
            ratio = getliquidityratio(tokenA, tokenB);
            
            require(
                (_amount0 * 10**4) / _amount1 == ratio,
                "liquidity must be in ratio"
            );
        }

        require(
            IERC20(tokenA).balanceOf(caller) > _amount0 &&
                IERC20(tokenB).balanceOf(caller) > _amount1,
            "not enough balance"
        );
        IERC20(tokenA).transferFrom(caller, address(pair), _amount0);
        IERC20(tokenB).transferFrom(caller, address(pair), _amount1);
        pair.deposit(_amount0, _amount1, caller);

        pair.updateAfterLiquidity(tokenA, _amount0, _amount1);

        emit liquidityAdded(
            pair,
            tokenA,
            tokenB,
            _amount0,
            _amount1,
            block.timestamp
        );
        return ("liquidity added");
    }

    function RemoveLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _LPtoken
    ) public returns (string memory) {
        address caller = msg.sender;

        require(getPair[_tokenA][_tokenB] != address(0), "create pair firstly");
        (address tokenA, address tokenB) = sortminTOmax(_tokenA, _tokenB);
        pool pair = pool(getPair[tokenA][tokenB]);

        require(
            pair.balanceOf(caller) >= _LPtoken,
            "not have enough liquidity"
        );
        (uint256 amountToken0, uint256 amountToken1) = pair.withdraw(
            _LPtoken,
            caller
        );

        pair.updateAfterRemoveLiquidity(tokenA, amountToken0, amountToken1);
        pair.approveforliquidity(amountToken0, amountToken1);
        IERC20(tokenA).transferFrom(address(pair), caller, amountToken0);
        IERC20(tokenB).transferFrom(address(pair), caller, amountToken1);

        emit liquidityRemoved(
            pair,
            tokenA,
            tokenB,
            amountToken0,
            amountToken1,
            block.timestamp
        );
        return "removed liquidity";
    }

    function getliquidityratio(address _tokenA, address _tokenB)
        public
        view
        returns (uint256)
    {
        require(ISpairExist(_tokenA, _tokenB), "pool does not exist");
        pool _address = pool(getPair[_tokenA][_tokenB]);
        require(ISpairExist(_tokenA, _tokenB), "pool does not exist");
        (uint256 reserveToken0, uint256 reserveToken1, ) = _address
            .getReserves();

        if (_address.token0() == _tokenA) {
            return (reserveToken0 * 10000) / reserveToken1;
        } else {
            return (reserveToken1 * 10000) / reserveToken0;
        }
    }

    function AmountIN(
        address tokenIN,
        address tokenOUT,
        uint256 amountOUT
    ) public view returns (uint256) {
        require(tokenIN != tokenOUT, "IDENTICAL_ADDRESSES");
        require(
            tokenIN != address(0) && tokenOUT != address(0),
            "ZERO_ADDRESS"
        );

        require(ISpairExist(tokenIN, tokenOUT), "create pair firstly");
        pool addr = pool(getPair[tokenIN][tokenOUT]);
        (uint256 reserveToken0, uint256 reserveToken1, ) = addr.getReserves();

        if (tokenIN == addr.token0()) {
            uint256 amountIn =(((reserveToken0 * amountOUT + amountOUT)*10000) /
                reserveToken1) /10000;
            return amountIn;
        } else {
            uint256 amountIn = (((reserveToken1 * amountOUT + amountOUT)*10000) /
                reserveToken0) /10000;
            return amountIn;
        }
    }

    function AmountOut(
        address tokenIN,
        uint256 amountIN,
        address tokenOUT
    ) public view returns (uint256 amountOUT) {
        require(tokenIN != tokenOUT, "IDENTICAL_ADDRESSES");
        require(
            tokenIN != address(0) && tokenOUT != address(0),
            "ZERO_ADDRESS"
        );

        require(ISpairExist(tokenIN, tokenOUT), "create pair firstly");
        pool addr = pool(getPair[tokenIN][tokenOUT]);
        (uint256 reserveToken0, uint256 reserveToken1, ) = addr.getReserves();

        uint256 Kconst = reserveToken0 * reserveToken1;

        if (tokenIN == addr.token0()) {
            uint256 reserve = reserveToken0 + amountIN;
            uint256 out = reserveToken1 - ((Kconst*10000 )/ reserve)/10000;
            return out;
        } else {
            uint256 reserve = reserveToken1 + amountIN;
            uint256 out = reserveToken0 - ((Kconst*10000 )/ reserve)/10000;
            return out;
        }
    }

    function swap(
        uint256 amountIN,
        address tokenIN,
        address tokenOUT,
        uint256 desiredOut
    ) public returns (uint256) {
        address caller = msg.sender;
        require(
            IERC20(tokenIN).balanceOf(caller) > amountIN,
            "not enough balance"
        );
        uint256 AmountOUT = AmountOut(tokenIN, amountIN, tokenOUT);
        require(desiredOut>=AmountOUT,"slippage exist more");
        pool _pool = pool(getPair[tokenIN][tokenOUT]);
        IERC20(tokenIN).transferFrom(caller, address(_pool), amountIN);
        _pool.approveforswap(tokenOUT, AmountOUT);
        IERC20(tokenOUT).transferFrom(address(_pool), caller, AmountOUT);
        _pool.updateAfterSwap(tokenIN, amountIN, AmountOUT);

        emit Swap(
            _pool,
            tokenIN,
            tokenOUT,
            amountIN,
            AmountOUT,
            block.timestamp
        );
        return AmountOUT;
    }

    function swaprationotpool(address[] memory token, uint256 _amountIn)
        public
        view
        returns (uint256)
    {
        uint256 amount = _amountIn;
        for (uint256 i = 0; i < (token.length) - 1; i++) {
            uint256 amountOut = AmountOut(token[i], amount, token[i + 1]);
            amount = amountOut;
        }
        return amount;
    }

    function pool_not_exist(address[] memory token, uint256 _amount,uint desiredAmount)
        public
        returns (uint256)
    {
        address _caller = msg.sender;
        uint256 amount = _amount;
        IERC20(token[0]).transferFrom(_caller, address(this), amount);
        for (uint256 i = 0; i < (token.length) - 1; i++) {
            if (i < (token.length) - 2) {
                uint256 AmountOUT = AmountOut(token[i], amount, token[i + 1]);
                pool _pool = pool(getPair[token[i]][token[i + 1]]);
                _pool.approveforswap(token[i + 1], AmountOUT);
                IERC20(token[i]).transfer(address(_pool), amount);
                IERC20(token[i + 1]).transferFrom(
                    address(_pool),
                    address(this),
                    AmountOUT
                );
                _pool.updateAfterSwap(token[i], amount, AmountOUT);
                emit Swap(
                    _pool,
                    token[i],
                    token[i + 1],
                    amount,
                    AmountOUT,
                    block.timestamp
                );
                amount = AmountOUT;
            } else {
                uint256 AmountOUT = AmountOut(token[i], amount, token[i + 1]);
                pool _pool = pool(getPair[token[i]][token[i + 1]]);
                _pool.approveforswap(token[i + 1], AmountOUT);
                IERC20(token[i]).transfer(address(_pool), amount);
                IERC20(token[i + 1]).transferFrom(
                    address(_pool),
                    _caller,
                    AmountOUT
                );
                _pool.updateAfterSwap(token[i], amount, AmountOUT);
                emit Swap(
                    _pool,
                    token[i],
                    token[i + 1],
                    amount,
                    AmountOUT,
                    block.timestamp
                );
                amount = AmountOUT;
            }
        }
        require(desiredAmount>=amount,"slippage exceed");
        return amount;
    }
}