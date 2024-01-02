// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IExchange {
    function depositUSDC(uint256 _amount) external;

    function depositDAI(uint256 _amount) external;

    function buyDAI() external;

    function sellDAI() external;
}