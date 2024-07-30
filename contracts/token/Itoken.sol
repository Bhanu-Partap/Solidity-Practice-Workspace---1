// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../registry/interface/IIdentityRegistry.sol";

import "../Compliance/modular/IModularCompliance.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev interface
interface IToken is IERC20 {
    event UpdatedTokenInformation(
        string indexed _newName,
        string indexed _newSymbol,
        uint8 _newDecimals,
        string _newVersion,
        address indexed _newOnchainID
    );

    event IdentityRegistryAdded(address indexed _identityRegistry);

    event ComplianceAdded(address indexed _compliance);

    event RecoverySuccess(
        address indexed _lostWallet,
        address indexed _newWallet,
        address indexed _investorOnchainID
    );

    event AddressFrozen(
        address indexed _userAddress,
        bool indexed _isFrozen,
        address indexed _owner
    );

    event TokensFrozen(address indexed _userAddress, uint256 _amount);

    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);

    event Paused(address _userAddress);

    event Unpaused(address _userAddress);

    function setName(string calldata _name) external;

    function setSymbol(string calldata _symbol) external;

    function setOnchainID(address _onchainID) external;

    function pause() external;

    function unpause() external;

    function setAddressFrozen(address _userAddress, bool _freeze) external;

    function freezePartialTokens(address _userAddress, uint256 _amount)
        external;

    function unfreezePartialTokens(address _userAddress, uint256 _amount)
        external;

    function setIdentityRegistry(address _identityRegistry) external;

    function setCompliance(address _compliance) external;

    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function mint(address _to, uint256 _amount) external;

    function burn(address _userAddress, uint256 _amount) external;

    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external returns (bool);

    function batchTransfer(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;

    function batchMint(address[] calldata _toList, uint256[] calldata _amounts)
        external;

    function batchBurn(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;

    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    ) external;

    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;

    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;

    function decimals() external view returns (uint8);

    function name() external view returns (string memory);

    function onchainID() external view returns (address);

    function symbol() external view returns (string memory);

    function version() external view returns (string memory);

    function identityRegistry() external view returns (IIdentityRegistry);

    function compliance() external view returns (IModularCompliance);

    function paused() external view returns (bool);

    function isFrozen(address _userAddress) external view returns (bool);

    function getFrozenTokens(address _userAddress)
        external
        view
        returns (uint256);
}
