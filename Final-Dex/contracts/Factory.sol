// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Pool.sol";
import "hardhat/console.sol";
import {erc20token} from "./Token.sol";


contract factory  {
    uint16 public fee = 30;
    // uint16 internal maxSlippage=3 ; // max slippage 3%
    uint256 private unlocked = 1;
    uint256 public gasFeePercentage = 50; // 0.5% gas fee
    // uint256 public orderCount;
    // mapping(uint256 => limitOrder) public orders;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairsAddress;
    address public constant withdrawGasAddress = 0x6a6a02f0F6CaBCE3D202d3f7cfAA3a15e7914943;

// Limit order
    // struct limitOrder {
    //     address user;
    //     address tokenIn;
    //     address tokenOut;
    //     uint256 amountIn;
    //     uint256 amountOutMin;
    //     uint256 targetPrice;
    //     uint256 expiry;
    //     bool isBuyOrder;
    //     bool isActive;
    // }

    event PairCreated(address token0, address token1, pool pair);
    event liquidityAdded(
        pool pair,
        address token0,
        address token1,
        uint256 quant0,
        uint256 quant1,
        uint256 time
    );
    event liquidityRemoved(
        pool pair,
        address token0,
        address token1,
        uint256 quant0,
        uint256 quant1,
        uint256 time
    );
    event Swap(
        pool pair,
        address tokenIN,
        address tokenOUT,
        uint256 quantIN,
        uint256 quantOUT,
        uint256 time
    );

    // event OrderPlaced(uint256 indexed orderId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 priceLimit, bool isBuyOrder);
    // event OrderExecuted(uint256 indexed orderId, address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    // event LimitOrderCancelled(uint256 indexed orderId, address indexed user);

    modifier lock() {
        require(unlocked == 1, "DEX: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyWithdrawAddress() {
        require(msg.sender == withdrawGasAddress, "Caller is not authorized");
        _;
    }

    // function placeLimitOrder(address tokenIn ,address tokenOut, uint256 amountIn, uint256 targetPrice, bool isBuyOrder, uint32 _deadline) public lock  {
    //     require(msg.sender != address(0),"User address can't be null");
    //     require(tokenIn != address(0) && tokenOut != address(0),"Token Addresses can't be zero");
    //     require(amountIn > 0, "AmountIn must be greater than zero");
    //     uint256 amountOutMin = AmountOut(tokenIn, tokenOut, amountIn);
    //     orders[orderCount] = limitOrder({
    //         user: msg.sender,
    //         tokenIn: tokenIn,
    //         tokenOut: tokenOut,
    //         amountIn: amountIn,
    //         amountOutMin: amountOutMin,
    //         targetPrice: targetPrice,
    //         isBuyOrder: isBuyOrder,
    //         // expiry: block.timestamp + 1 hours, // 1 hour expiry time
    //         expiry: _deadline,
    //         isActive: true
    //     });

    //     emit OrderPlaced(orderCount, msg.sender, tokenIn, tokenOut, amountIn, amountOutMin, targetPrice, isBuyOrder);
    //     orderCount++;
    // }


    // function executeLimitOrder(uint256 _id,address tokenIn, address tokenOut,uint256 amountIn, uint256 desiredOut) public returns(string memory) {
    //     limitOrder storage order = orders[_id];
    //     require(order.isActive,"Order doesn't exist or is already executed");
    //     require(block.timestamp < order.expiry,"Order Expired");
    //     uint256 getCurrentPrice = getReserveratio(tokenIn, tokenOut);
    //     console.log(getCurrentPrice,"here's the current price of Token A");
    //     uint256 targetPrice = order.targetPrice ;
    //     console.log(targetPrice,"Target Price of the order");
    //     // IERC20(tokenIn).transferFrom(order.user, address(this), amountIn);
    //     if(order.isBuyOrder){
    //          if (getCurrentPrice <= targetPrice){
    //             console.log("Buy Order Execution");
    //             swapForLimit(amountIn, tokenIn, tokenOut, desiredOut);
    //             console.log("Swapp done buy order");
    //             emit OrderExecuted(_id, msg.sender, tokenIn, tokenOut, amountIn, desiredOut);
    //             delete orders[_id]; // reduce the storage from the contract, and the executed orders are still stored on the db.
    //             return "Buy Order Executed";
    //     }
    //         else{
    //             return "Price Not Reached";
    //             }
    //     }
    //     else{
    //         if(getCurrentPrice >= targetPrice){
    //             console.log("Sell Order Execution");
    //             swapForLimit(amountIn, tokenIn, tokenOut, desiredOut);
    //             console.log("Swapp done sell order");
    //             emit OrderExecuted(_id, msg.sender, tokenIn, tokenOut, amountIn, desiredOut);
    //             delete orders[_id]; 
    //             return "Sell Order Executed";
    //         }
    //         else{
    //             return "Price Not Reached";
    //         }
    //     }
    // }


    // function cancelLimitOrder(uint256 _id )public lock returns(string memory){
    //     limitOrder storage order = orders[_id];
    //     require(order.isActive == true,"Order doesn't exist or is already executed");
    //     require(order.user == msg.sender, "Only the order initiator can cancel the order");
    //     //if expired order gets deleted
    //     if(block.timestamp >order.expiry){
    //         delete orders[_id];
    //         emit LimitOrderCancelled(_id,msg.sender);
    //         return "Order cancelled successfully";
    //     }
    //     // if not expired then let user delete their order,if they want to
    //     delete orders[_id];
    //     emit LimitOrderCancelled(_id,msg.sender);
    //     return "Order cancelled successfully";
    // }


    function concatenateStrings(string memory str1, string memory str2)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(str1, "-", str2));
    }


    function LptokenName(address tokenA, address tokenB)
        internal
        view
        returns (string memory LpName, string memory LpSymbol)
    {
        LpName = concatenateStrings(ERC20(tokenA).name(), ERC20(tokenB).name());
        LpSymbol = concatenateStrings(
            ERC20(tokenA).symbol(),
            ERC20(tokenB).symbol()
        );
    }

    function convertToTargetedPrecison(address token)
        internal
        view
        returns (uint256)
    {
        uint8 decimal = ERC20(token).decimals();
        uint8 RequiredPrecison = 18 - decimal;
        return 10**RequiredPrecison;
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
        internal
        returns (pool Pair)
    {
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(!ISpairExist(tokenA, tokenB), "PAIR_EXISTS");

        (address token0, address token1) = sortminTOmax(tokenA, tokenB);
        (string memory Name, string memory Symbol) = LptokenName(
            tokenA,
            tokenB
        );
        pool pair = new pool(token0, token1, address(this), Name, Symbol);
        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair); // populate mapping in the reverse direction
        address pairAddress = address(pair);
        emit PairCreated(token0, token1, pair);
        allPairsAddress.push(pairAddress);
        return pair;
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
    ) public lock returns (string memory) {
        address caller = msg.sender;
        uint256 ratio;
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        pool pair;
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        if (!ISpairExist(tokenA, tokenB)) {
            pair = createPair(tokenA, tokenB);
        } else {
            pair = pool(getPair[tokenA][tokenB]);
            ratio = getReserveratio(tokenA, tokenB);
            uint256 TokenBLiquidity = getliquidityOutperIn(
                _amount0,
                tokenA,
                tokenB
            );
            require(TokenBLiquidity == _amount1, "liquidity must be in ratio");
            // require(
            //     ((_amount0 * convertToTargetedPrecison(tokenA) * 10**18) /
            //         (convertToTargetedPrecison(tokenB) * _amount1)) /
            //         10**17 ==
            //         ratio / 10**17,
            //     "liquidity must be in ratio"
            // );
        }

        require(
            IERC20(tokenA).balanceOf(caller) >= _amount0 &&
                IERC20(tokenB).balanceOf(caller) >= _amount1,
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
    ) public lock returns (string memory) {
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

    function getReserveratio(address _tokenA, address _tokenB)
        public
        view
        returns (uint256)
    {
        require(ISpairExist(_tokenA, _tokenB), "pool does not exist");
        pool _address = pool(getPair[_tokenA][_tokenB]);

        (uint256 reserveToken0, uint256 reserveToken1, ) = _address
            .getReserves();

        if (_address.token0() == _tokenA) {
            return
                (reserveToken0 * convertToTargetedPrecison(_tokenA) * 10**18) /
                (convertToTargetedPrecison(_tokenB) * reserveToken1);
        } else {
            return ((reserveToken1 *
                convertToTargetedPrecison(_tokenA) *
                10**18) / (convertToTargetedPrecison(_tokenB) * reserveToken0));
        }
    }

    function getliquidityOutperIn(
        uint256 input,
        address _tokenA,
        address _tokenB
    ) public view returns (uint256) {
        uint256 liquidityOut = (input *
            convertToTargetedPrecison(_tokenA) *
            10**18) /
            (getReserveratio(_tokenA, _tokenB) *
                convertToTargetedPrecison(_tokenB));
        // uint256 liquidityOut = (input * getReserveratio(_tokenB, _tokenA)) /
        //     convertToTargetedPrecison(_tokenB);
        return liquidityOut;
    }

    function AmountIN(
        address tokenIN,
        address tokenOUT,
        uint256 amountOUT
    ) public view returns (uint256) {
        uint256 tokenINprecision = convertToTargetedPrecison(tokenIN);
        uint256 tokenOutprecision = convertToTargetedPrecison(tokenOUT);
        require(tokenIN != tokenOUT, "IDENTICAL_ADDRESSES");
        require(
            tokenIN != address(0) && tokenOUT != address(0),
            "ZERO_ADDRESS"
        );

        require(ISpairExist(tokenIN, tokenOUT), "create pair firstly");
        pool addr = pool(getPair[tokenIN][tokenOUT]);
        (uint256 reserveToken0, uint256 reserveToken1, ) = addr.getReserves();

        if (tokenIN == addr.token0()) {
            uint256 amountIn = ((1000 *
                reserveToken0 *
                amountOUT *
                tokenINprecision *
                tokenOutprecision) /
                ((reserveToken1 - amountOUT) * 997 * tokenOutprecision));
            return (amountIn / convertToTargetedPrecison(tokenIN)) + 1;
        } else {
            uint256 amountIn = ((1000 *
                reserveToken1 *
                amountOUT *
                tokenINprecision *
                tokenOutprecision) /
                ((reserveToken0 - amountOUT) * 997 * tokenOutprecision));
            return (amountIn / convertToTargetedPrecison(tokenIN)) + 1;
        }
    }

    function AmountOut(
        address tokenIN,
        address tokenOUT,
        uint256 amountIN
    ) public view returns (uint256 amountOUT) {
        uint256 tokenINprecision = convertToTargetedPrecison(tokenIN);
        uint256 tokenOutprecision = convertToTargetedPrecison(tokenOUT);
        require(tokenIN != tokenOUT, "IDENTICAL_ADDRESSES");
        require(
            tokenIN != address(0) && tokenOUT != address(0),
            "ZERO_ADDRESS"
        );

        require(ISpairExist(tokenIN, tokenOUT), "create pair firstly");
        pool addr = pool(getPair[tokenIN][tokenOUT]);
        (uint256 reserveToken0, uint256 reserveToken1, ) = addr.getReserves();

        uint256 Kconst = reserveToken0 *
            reserveToken1 *
            tokenINprecision *
            tokenOutprecision;

        if (tokenIN == addr.token0()) {
            uint256 reserve = ((reserveToken0 * 10 + (amountIN * 997) / 100) /
                10) * tokenINprecision;
            uint256 out = reserveToken1 *
                tokenOutprecision -
                (Kconst / reserve);
            return out / convertToTargetedPrecison(tokenOUT);
        } else {
            uint256 reserve = ((reserveToken1 * 10 + (amountIN * 997) / 100) /
                10) * tokenINprecision;
            uint256 out = reserveToken0 *
                tokenOutprecision -
                (Kconst / reserve);
            return out / convertToTargetedPrecison(tokenOUT);
        }
    }


    function swap(
        uint256 amountIN,
        address tokenIN,
        address tokenOUT,
        uint256 desiredOut
    ) public lock returns (uint256) {
        address caller = msg.sender;
        require(
            IERC20(tokenIN).balanceOf(caller) >= amountIN,
            "not enough balance"
        );
        uint256 AmountOUT = AmountOut(tokenIN, tokenOUT, amountIN);
        require(desiredOut >= AmountOUT, "slippage exist more");
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


    // Function to withdraw gas fee securely
    function withdraw(uint256 _amount,address tokenB) external  {
        uint256 contractTokenBalance = IERC20(tokenB).balanceOf(address(this));
        require(contractTokenBalance >= _amount, "Insufficient contract token balance");

        bool success = IERC20(tokenB).transfer(withdrawGasAddress, _amount);
        require(success, "Token transfer failed.");
    }


    function swapForLimit(
        uint256 amountIN,
        address tokenIN,
        address tokenOUT,
        uint256 desiredOut
    ) public lock returns (uint256) {
        address caller = msg.sender;
        require(
            IERC20(tokenIN).balanceOf(caller) >= amountIN,
            "not enough balance"
        );
        uint256 amountOUT = AmountOut(tokenIN, tokenOUT, amountIN);
        console.log("AmountOut : ", amountOUT);
        require(desiredOut >= amountOUT, "slippage exist more");
        pool _pool = pool(getPair[tokenIN][tokenOUT]);
        IERC20(tokenIN).transferFrom(caller, address(_pool), amountIN);
        _pool.approveforswap(tokenOUT, amountOUT);
        IERC20(tokenOUT).transferFrom(address(_pool), address(this),amountOUT);

        // before tx
        // 790000000000000 user token a 
        // 809020778394107 user token b
        // 9066108938801 amount out


        // after tx 
        // 780000000000000 user token a 
        // 818041556788214 user token b
        // 7540920499133 amount out after limit swap

        // 9.020778394×10¹² final amount out of token b 
        // 45330544694 gas used
        // 45330544694 factory contract recieved token b amount as gas cost



        // Calculate gas fee in the output token
        uint256 gasFee = (amountOUT * gasFeePercentage) / 10000; // Deduct 0.5%
        console.log("gasFee : ", gasFee);
        // Final output amount after deducting gas fee
        uint256 finalAmountOUT = amountOUT - gasFee;
        console.log("finalAmountOUT : ", finalAmountOUT);

        IERC20(tokenOUT).transfer(caller,finalAmountOUT);
        _pool.updateAfterSwap(tokenIN, amountIN, finalAmountOUT);
        // IERC20(tokenOUT).transferFrom(address(this), order.user, AmountOUT);

        emit Swap(
            _pool,
            tokenIN,
            tokenOUT,
            amountIN,
            finalAmountOUT,
            block.timestamp
        );
        return finalAmountOUT;
    }












    // function swapForLimit(
    //     uint256 amountIN,
    //     address tokenIN,
    //     address tokenOUT,
    //     uint256 desiredOut
    // ) public lock returns (uint256) {
    //     address caller = address(this);
    //     require(
    //         IERC20(tokenIN).balanceOf(caller) >= amountIN,
    //         "not enough balance"
    //     );
    //     uint256 AmountOUT = AmountOut(tokenIN, tokenOUT, amountIN);
    //     require(desiredOut >= AmountOUT, "slippage exist more");
    //     pool _pool = pool(getPair[tokenIN][tokenOUT]);
    //     IERC20(tokenIN).transferFrom(caller, address(_pool), amountIN);
    //     _pool.approveforswap(tokenOUT, AmountOUT);
    //     IERC20(tokenOUT).transferFrom(address(_pool), caller, AmountOUT);
    //     _pool.updateAfterSwap(tokenIN, amountIN, AmountOUT);
    //     // IERC20(tokenOUT).transferFrom(address(this), order.user, AmountOUT);

    //     emit Swap(
    //         _pool,
    //         tokenIN,
    //         tokenOUT,
    //         amountIN,
    //         AmountOUT,
    //         block.timestamp
    //     );
    //     return AmountOUT;
    // }


// // function for getting the desired amount out for multi hop trade
//     function swapOutIfNotpool(address[] memory token, uint256 _amountIn)
//         public
//         view
//         returns (uint256)
//     {
//         uint256 amount = _amountIn;
//         for (uint256 i = 0; i < (token.length) - 1; i++) {
//             uint256 amountOut = AmountOut(token[i], token[i + 1], amount);
//             amount = amountOut;
//         }
//         return amount;
//     }

// // function for multi-hop trade
//     function swap_If_pool_not_exist(
//         address[] memory token,
//         uint256 _amount,
//         uint256 desiredAmount
//     ) public lock returns (uint256) {
//         address _caller = msg.sender;
//         uint256 amount = _amount;
//         IERC20(token[0]).transferFrom(_caller, address(this), amount);
//         for (uint256 i = 0; i < (token.length) - 1; i++) {
//             if (i < (token.length) - 2) {
//                 uint256 AmountOUT = AmountOut(token[i], token[i + 1], amount);
//                 pool _pool = pool(getPair[token[i]][token[i + 1]]);
//                 _pool.approveforswap(token[i + 1], AmountOUT);
//                 IERC20(token[i]).transfer(address(_pool), amount);
//                 IERC20(token[i + 1]).transferFrom(
//                     address(_pool),
//                     address(this),
//                     AmountOUT
//                 );
//                 _pool.updateAfterSwap(token[i], amount, AmountOUT);
//                 emit Swap(
//                     _pool,
//                     token[i],
//                     token[i + 1],
//                     amount,
//                     AmountOUT,
//                     block.timestamp
//                 );
//                 amount = AmountOUT;
//             } else {
//                 uint256 AmountOUT = AmountOut(token[i], token[i + 1], amount);
//                 pool _pool = pool(getPair[token[i]][token[i + 1]]);
//                 _pool.approveforswap(token[i + 1], AmountOUT);
//                 IERC20(token[i]).transfer(address(_pool), amount);
//                 IERC20(token[i + 1]).transferFrom(
//                     address(_pool),
//                     _caller,
//                     AmountOUT
//                 );
//                 _pool.updateAfterSwap(token[i], amount, AmountOUT);
//                 emit Swap(
//                     _pool,
//                     token[i],
//                     token[i + 1],
//                     amount,
//                     AmountOUT,
//                     block.timestamp
//                 );
//                 amount = AmountOUT;
//             }
//         }
//         require(desiredAmount >= amount, "slippage exceed");

//         return amount;
//     }

}


