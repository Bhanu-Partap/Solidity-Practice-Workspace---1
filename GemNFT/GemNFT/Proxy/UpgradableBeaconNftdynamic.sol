// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import  "@openzeppelin/contracts@4.9.6/proxy/beacon/UpgradeableBeacon.sol";
// import  "@openzeppelin/contracts@4.9.6/access/Ownable.sol";
contract UpgradeNftCollection is   UpgradeableBeacon{
   constructor(address implementation) UpgradeableBeacon(implementation){}

}

