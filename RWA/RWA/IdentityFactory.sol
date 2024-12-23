// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/Initializable.sol";
//import "./interface/IIdentityFactory.sol";
import "./Identities/Identity.sol";

// import "./Identities/claimIssuer.sol";

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

    // function _deploy(uint8 salt, bytes memory bytecode)
    //     private
    //     returns (address)
    // {
    //     bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
    //     address addr;
    //     // solhint-disable-next-line no-inline-assembly
    //     assembly {
    //         let encoded_data := add(0x20, bytecode) // load initialization code.
    //         let encoded_size := mload(bytecode) // load init code's length.
    //         addr := create2(0, encoded_data, encoded_size, saltBytes)
    //         if iszero(extcodesize(addr)) {
    //             revert(0, 0)
    //         }
    //     }

    //     return addr;
    // }

    // mapping (address=>address) usertoclaimIssuer;
    // mapping(address=>bool) isregisteredClaimIssuer;
    function createidentity(address _useraddress) public onlyAdmin {
        require(
            !isregisteredIdentity[_useraddress],
            "you are already registered"
        );
        // bytes memory _code = type(Identity).creationCode;
        // address _address = _deploy(1,_code);
        address _address=address (new identities(_useraddress));

        usertoidentity[_useraddress] = _address;
        isregisteredIdentity[_useraddress] = true;
    }

    function getidentity(address _useraddress) public view returns (address) {
        return usertoidentity[_useraddress];
    }

    // function createClaimIssuer(address _useraddress) public returns(address){
    //     require(!isregisteredClaimIssuer[_useraddress],"you are already registered");
    //     address _address=address(new ClaimIssuers(_useraddress));
    //     usertoclaimIssuer[_useraddress]=_address;
    //      isregisteredClaimIssuer[_useraddress]=true;

    //     return _address;
    // }

    // function getClaimIssuer(address _useraddress) public view returns(address){
    //     return usertoclaimIssuer[_useraddress];
    // }
}
