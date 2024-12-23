// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
//import "@openzeppelin/contracts/access/Ownable.sol";
import "./halffactory.sol";
import "./Ifactory.sol";
import "../proxy/IProxy.sol";

contract mainfactory is Ifactory {
    struct Contracts {
        address tokenImplementation;
        address irImplementation;
        address mcImplementation;
        address irsImplementation;
        address ctrImplementation;
        address tirImplementation;
    }

    uint256 public salt;
    halffactory x = new halffactory();

    mapping(uint256 => Contracts) public alldata;

    function _deploy(uint256 _salt, bytes memory bytecode)
        private
        returns (address)
    {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(_salt)));
        address addr;

        assembly {
            let encoded_data := add(0x20, bytecode)
            let encoded_size := mload(bytecode)
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            // same thing can be done like this
            // addr := create2(0, add(bytecode, 0x20), mload(bytecode), saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        return addr;
    }

    function upgrade(address token) external {
        require(Token(token).owner() == msg.sender, "not owner");
        address ir = address(IToken(token).identityRegistry());
        IProxy(token).setImplementationAuthority(address(this));
        IProxy(ir).setImplementationAuthority(address(this));
        IProxy(address(IToken(token).compliance())).setImplementationAuthority(
            address(this)
        );
        IProxy(address(IIdentityRegistry(ir).identityStorage()))
            .setImplementationAuthority(address(this));
        IProxy(address(IIdentityRegistry(ir).topicsRegistry()))
            .setImplementationAuthority(address(this));
        IProxy(address(IIdentityRegistry(ir).issuersRegistry()))
            .setImplementationAuthority(address(this));
    }

    function deployall() public returns (address) {
        salt++;

        IClaimTopicsRegistry ctr = IClaimTopicsRegistry(
            x.claimtopicregistry(salt)
        );
        ITrustedIssuersRegistry cir = ITrustedIssuersRegistry(
            claimissuersregistry(salt)
        );

        IIdentityRegistryStorage irs = IIdentityRegistryStorage(
            x.identityregistrystorage(salt)
        );
        IIdentityRegistry ir = IIdentityRegistry(x.identityregistry(salt));

        IModularCompliance mc = IModularCompliance(x.modularcompliance(salt));

        IToken it = IToken(tokens(salt));
        alldata[salt] = Contracts(
            address(it),
            address(ir),
            address(mc),
            address(irs),
            address(ctr),
            address(cir)
        );
        return address(it);
    }

    function claimissuersregistry(uint256 _salt) internal returns (address) {
        bytes memory _code = type(TrustedIssuersRegistry).creationCode;
        return _deploy(_salt, _code);
    }

    function tokens(uint256 _salt) internal returns (address) {
        bytes memory _code = type(Token).creationCode;

        return _deploy(_salt, _code);
    }

    function getTokenImplementation() external view returns (address _address) {
        return alldata[salt].tokenImplementation;
    }

    function getCTRImplementation() external view returns (address _address) {
        return alldata[salt].ctrImplementation;
    }

    function getIRImplementation() external view returns (address _address) {
        return alldata[salt].irImplementation;
    }

    function getIRSImplementation() external view returns (address _address) {
        return alldata[salt].irsImplementation;
    }

    function getTIRImplementation() external view returns (address _address) {
        return alldata[salt].tirImplementation;
    }

    function getMCImplementation() external view returns (address _address) {
        return alldata[salt].mcImplementation;
    }
}
