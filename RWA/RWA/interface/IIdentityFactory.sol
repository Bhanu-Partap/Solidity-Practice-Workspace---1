// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IIdentityFactory {
    function createidentity(address _useraddress) external;

    function getidentity(address _useraddress) external view returns (address);
}
