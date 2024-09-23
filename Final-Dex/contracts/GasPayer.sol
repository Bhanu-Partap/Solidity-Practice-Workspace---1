// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GasPayment {
    address public owner;
    uint256 public gasFeeRate; // e.g., 1% represented as 100 (basis points)

    // Mapping to track fees collected per user
    mapping(address => mapping(address => uint256)) public userFees; // user => token => feeAmount

    event GasFeeCharged(address indexed user, address indexed token, uint256 feeAmount);
    event GasFeeWithdrawn(address indexed user, address indexed token, uint256 feeAmount);
    event GasFeeRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(uint256 _initialGasFeeRate) {
        owner = msg.sender;
        gasFeeRate = _initialGasFeeRate; // e.g., 100 = 1%
    }

    // Function to update the gas fee rate
    function updateGasFeeRate(uint256 _newRate) external onlyOwner {
        gasFeeRate = _newRate;
        emit GasFeeRateUpdated(_newRate);
    }

    // Function to charge gas fee when placing a limit order
    function chargeGasFee(address user, address token, uint256 amountIn) external {
        // Assuming the caller is the LimitOrder contract
        require(msg.sender != address(0), "Invalid caller");
        uint256 fee = (amountIn * gasFeeRate) / 10000; // Calculate fee based on basis points
        require(
            IERC20(token).balanceOf(user) >= fee,
            "Insufficient balance for gas fee"
        );

        // Transfer fee from user to GasPayment contract
        bool success = IERC20(token).transferFrom(user, address(this), fee);
        require(success, "Gas fee transfer failed");

        // Record the fee
        userFees[user][token] += fee;

        emit GasFeeCharged(user, token, fee);
    }

    // Function for users to withdraw their accumulated gas fees (if applicable)
    function withdrawGasFee(address token) external {
        uint256 fee = userFees[msg.sender][token];
        require(fee > 0, "No gas fees to withdraw");

        userFees[msg.sender][token] = 0;
        bool success = IERC20(token).transfer(msg.sender, fee);
        require(success, "Gas fee withdrawal failed");

        emit GasFeeWithdrawn(msg.sender, token, fee);
    }

    // Function for the owner to withdraw accumulated gas fees
    function ownerWithdraw(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient contract balance"
        );
        bool success = IERC20(token).transfer(owner, amount);
        require(success, "Withdrawal failed");
    }

    


}
