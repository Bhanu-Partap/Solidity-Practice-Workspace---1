import "./Erc-20.sol";

contract LpTokens{

    erc20 token0;
    erc20 token1;
    erc20 lptokens;


    constructor(address _token0, address _token1) {
        token0 = erc20(_token0);
        token1 = erc20(_token1);
    }

    function mintingLpTokens(uint _amount0, uint _amount1) external {
        require(_amount0 > 0 && _amount1 > 0, "Amounts must be greater than zero");
        uint256 totalSupply = lptokens.totalSupply(); 
        require(token0.transferFrom(msg.sender, address(this), _amount0), "TokenA transfer failed");
        require(token1.transferFrom(msg.sender, address(this), _amount1), "TokenB transfer failed");
        lptokens.mint(msg.sender,_amount0 + _amount1);
    }
}

