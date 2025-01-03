// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./Identity.sol";


contract IDfactory is Initializable {
    mapping(address => address) usertoidentity;
    mapping(address => bool) isregisteredIdentity;

    function initialize(address admin) public initializer {
        Admin = admin;
    }

    address public Admin;
    modifier onlyAdmin() {
        require(msg.sender == Admin, "Caller must be admin");
        _;
    }

    function createidentity(address _useraddress) public onlyAdmin {
        require(
            !isregisteredIdentity[_useraddress],
            "you are already registered"
        );
        address _address=address (new identities(_useraddress));

        usertoidentity[_useraddress] = _address;
        isregisteredIdentity[_useraddress] = true;
    }

    function getidentity(address _useraddress) public view returns (address) {
        return usertoidentity[_useraddress];
    }
}
