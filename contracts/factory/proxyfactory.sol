// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
//import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../token/token.sol";
import "../registry/implementation/IdentityRegistry.sol";
import "../proxy/TokenProxy.sol";
import "../proxy/ClaimTopicsRegistryProxy.sol";
import "../proxy/IdentityRegistryProxy.sol";
import "../proxy/IdentityRegistryStorageProxy.sol";
import "../proxy/TrustedIssuersRegistryProxy.sol";
import "../proxy/ModularComplianceProxy.sol";
import "../registry/interface/IClaimTopicsRegistry.sol";
import "../Compliance/modular/IModularCompliance.sol";
import "../registry/interface/ITrustedIssuersRegistry.sol";
import "../registry/interface/IIdentityRegistryStorage.sol";

contract proxyfactory {
    event tokenaddress(address _contractaddress);

    struct asset {
        address owner;
        string assetname;
        uint256 assetprice;
        string token_name;
        string token_symbol;
    }

    struct Contracts {
        address tokenImplementation;
        address irImplementation;
        address mcImplementation;
        address irsImplementation;
        address ctrImplementation;
        address tirImplementation;
    }
    bytes32 constant AGENT_ROLE =
        0xcab5a0bfe0b79d2c4b1c2e02599fa044d115b7511f9659307cb4276950967709;

    bytes32 constant OWNER_ROLE =
        0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e;
    uint256 salt;
    address implementationAuthority;
    mapping(address => mapping(string => Contracts)) public _alldata;
    mapping(string => asset) public assets;
    mapping(string => string) tokentoasset;

    mapping(string => bool) isassets;
    mapping(address => asset[]) ownertoasset;

    function tokendetail(string memory _tokenname)
        public
        view
        returns (asset memory)
    {
        return assets[tokentoasset[_tokenname]];
    }

    function setimplementationAuthority(address _implementationauthority)
        public
    {
        implementationAuthority = _implementationauthority;
    }

    function _deploy(uint256 _salt, bytes memory bytecode)
        private
        returns (address)
    {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(_salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode) // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        return addr;
    }

    function deployall(
        address owner,
        string memory assetname,
        uint256 assetprice,
        string memory name,
        string memory symbol,
        uint16 maxsupply
    ) external returns (address) {
        require(!isassets[assetname], "assestname already exist");
        salt++;

        ITrustedIssuersRegistry tir = ITrustedIssuersRegistry(
            _deployTIR(salt, implementationAuthority)
        );
        IClaimTopicsRegistry ctr = IClaimTopicsRegistry(
            _deployCTR(salt, implementationAuthority)
        );
        IModularCompliance mc = IModularCompliance(
            _deployMC(salt, implementationAuthority)
        );
        IIdentityRegistryStorage irs = IIdentityRegistryStorage(
            _deployIRS(salt, implementationAuthority)
        );

        IIdentityRegistry ir = IIdentityRegistry(
            _deployIR(
                salt,
                implementationAuthority,
                address(tir),
                address(ctr),
                address(irs)
            )
        );

        IToken token = IToken(
            _deployToken(
                salt,
                implementationAuthority,
                address(ir),
                address(mc),
                name,
                symbol,
                18,
                maxsupply
            )
        );
        ownertoasset[owner].push(
            asset(owner, assetname, assetprice, name, symbol)
        );

        holddata(
            owner,
            assetname,
            address(token),
            address(ir),
            address(mc),
            address(irs),
            address(ctr),
            address(tir)
        );

        isassets[assetname] = true;
        assets[assetname] = asset(owner, assetname, assetprice, name, symbol);
        tokentoasset[name] = assetname;
        irs.bindIdentityRegistry(address(ir));
        (OwnableUpgradeable(address(token))).transferOwnership(owner);
        (OwnableUpgradeable(address(tir))).transferOwnership(owner);
        (OwnableUpgradeable(address(ctr))).transferOwnership(owner);
        (OwnableUpgradeable(address(mc))).transferOwnership(owner);

        emit tokenaddress(address(token));

        return address(token);
    }

    function holddata(
        address owner,
        string memory assetname,
        address token,
        address ir,
        address mc,
        address irs,
        address ctr,
        address tir
    ) internal {
        _alldata[owner][assetname] = Contracts(
            address(token),
            address(ir),
            address(mc),
            address(irs),
            address(ctr),
            address(tir)
        );

        Token(address(token)).grantRole(bytes32(0), owner);
        Token(address(token)).grantRole(OWNER_ROLE, owner);
        Token(address(token)).grantRole(AGENT_ROLE, owner);
        IdentityRegistry(address(ir)).grantRole(bytes32(0), owner);
        IdentityRegistry(address(ir)).grantRole(OWNER_ROLE, owner);
        IdentityRegistry(address(ir)).grantRole(AGENT_ROLE, owner);
    }

    function _deployToken(
        uint256 _salt,
        address _implementationAuthority,
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 maxSupply
    ) internal returns (address) {
        bytes memory _code = type(TokenProxy).creationCode;
        bytes memory _constructData = abi.encode(
            _implementationAuthority,
            _identityRegistry,
            _compliance,
            _name,
            _symbol,
            _decimals,
            maxSupply
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    function _deployTIR(uint256 _salt, address _implementationAuthority)
        internal
        returns (address)
    {
        bytes memory _code = type(TrustedIssuersRegistryProxy).creationCode;

        bytes memory _constructData = abi.encode(_implementationAuthority);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    function _deployCTR(uint256 _salt, address _implementationAuthority)
        internal
        returns (address)
    {
        bytes memory _code = type(ClaimTopicsRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    function _deployIR(
        uint256 _salt,
        address _implementationAuthority,
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) internal returns (address) {
        bytes memory _code = type(IdentityRegistryProxy).creationCode;
        bytes memory _constructData = abi.encode(
            _implementationAuthority,
            _trustedIssuersRegistry,
            _claimTopicsRegistry,
            _identityStorage
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    function _deployIRS(uint256 _salt, address _implementationAuthority)
        internal
        returns (address)
    {
        bytes memory _code = type(IdentityRegistryStorageProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    function _deployMC(uint256 _salt, address _implementationAuthority)
        internal
        returns (address)
    {
        bytes memory _code = type(ModularComplianceProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }
}
