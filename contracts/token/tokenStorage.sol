// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
import "../Compliance/modular/IModularCompliance.sol";
import "../registry/interface/IIdentityRegistry.sol";

contract TokenStorage {
    // ERC20 basic variables
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    mapping(address => mapping(address => bool)) transcationdata;
    uint256 internal _totalSupply;

    // Token information
    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 internal _tokenDecimals;
    uint16 public maxsupply;
    address internal _tokenOnchainID;
    string internal constant _TOKEN_VERSION = "4.0.1";

    // Variables of freeze and pause functions
    mapping(address => bool) internal _frozen;
    mapping(address => uint256) internal _frozenTokens;

    bool internal _tokenPaused = false;

    IIdentityRegistry internal _tokenIdentityRegistry;

    IModularCompliance internal _tokenCompliance;

    // uint256[49] private __gap;
}
