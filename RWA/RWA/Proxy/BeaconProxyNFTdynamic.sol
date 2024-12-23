// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts@4.9.6/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts@4.9.6/access/Ownable.sol";

contract nftCollectionBeacon is BeaconProxy {
    constructor(
        address beacon,
        string memory name,
        string memory symbol,
        address identity,
        address admin,
        address owner,
        address _nftfactoryaddress
    ) BeaconProxy(beacon, "") {
        address implementation = _implementation();
        (bool success, ) = implementation.delegatecall(
            abi.encodeWithSignature(
                "initialize(string,string,address,address,address,address)",
                name,
                symbol,
                identity,
                admin,
                owner,
                _nftfactoryaddress
            )
        );
        require(success, "Initialization failed.");
    }
}
