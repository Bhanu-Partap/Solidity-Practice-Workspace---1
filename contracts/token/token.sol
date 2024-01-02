// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./Itoken.sol";
import "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import "./tokenStorage.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Token is
    IToken,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    TokenStorage
{
    modifier whenNotPaused() {
        require(!_tokenPaused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_tokenPaused, "Pausable: not paused");
        _;
    }

    bytes32 public constant AGENT_ROLE =
        0xcab5a0bfe0b79d2c4b1c2e02599fa044d115b7511f9659307cb4276950967709;

    bytes32 public constant OWNER_ROLE =
        0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e;

    function init(
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 _maxsupply
    ) external initializer {
        _grantRole(bytes32(0), _msgSender());

        _grantRole(OWNER_ROLE, _msgSender());

        _grantRole(AGENT_ROLE, _msgSender());

        require(owner() == address(0), "already initialized");
        require(
            _identityRegistry != address(0) && _compliance != address(0),
            "invalid argument - zero address"
        );
        require(
            keccak256(abi.encode(_name)) != keccak256(abi.encode("")) &&
                keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")),
            "invalid argument - empty string"
        );

        __Ownable_init();
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenPaused = true;
        _tokenDecimals = _decimals;
        setIdentityRegistry(_identityRegistry);
        setCompliance(_compliance);
        maxsupply = _maxsupply;
        emit UpdatedTokenInformation(
            _tokenName,
            _tokenSymbol,
            _tokenDecimals,
            _TOKEN_VERSION,
            address(0)
        );
    }

    function paymentapprovedbyowner(address _to) external {
        require(msg.sender == owner(), "not owner");
        transcationdata[owner()][_to] = true;
    }

    function approve(address _spender, uint256 _amount)
        external
        virtual
        override
        returns (bool)
    {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowances[msg.sender][_spender] + (_addedValue)
        );
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowances[msg.sender][_spender] - _subtractedValue
        );
        return true;
    }

    function setName(string calldata _name)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        require(
            keccak256(abi.encode(_name)) != keccak256(abi.encode("")),
            "invalid argument - empty string"
        );
        _tokenName = _name;
        emit UpdatedTokenInformation(
            _tokenName,
            _tokenSymbol,
            _tokenDecimals,
            _TOKEN_VERSION,
            _tokenOnchainID
        );
    }

    function setSymbol(string calldata _symbol)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        require(
            keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")),
            "invalid argument - empty string"
        );
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(
            _tokenName,
            _tokenSymbol,
            _tokenDecimals,
            _TOKEN_VERSION,
            _tokenOnchainID
        );
    }

    function setOnchainID(address _onchainID)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        _tokenOnchainID = _onchainID;
        emit UpdatedTokenInformation(
            _tokenName,
            _tokenSymbol,
            _tokenDecimals,
            _TOKEN_VERSION,
            _tokenOnchainID
        );
    }

    function pause() external override onlyRole(AGENT_ROLE) whenNotPaused {
        _tokenPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() external override onlyRole(AGENT_ROLE) whenPaused {
        _tokenPaused = false;
        emit Unpaused(msg.sender);
    }

    function batchTransfer(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override whenNotPaused returns (bool) {
        require(!_frozen[_to] && !_frozen[_from], "wallet is frozen");
        require(
            _amount <= balanceOf(_from) - (_frozenTokens[_from]),
            "Insufficient Balance"
        );
        if (
            _tokenIdentityRegistry.isVerified(_to) &&
            _tokenCompliance.canTransfer(_from, _to, _amount)
        ) {
            _approve(
                _from,
                msg.sender,
                _allowances[_from][msg.sender] - (_amount)
            );
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    function batchMint(address[] calldata _toList, uint256[] calldata _amounts)
        external
        override
    {
        for (uint256 i = 0; i < _toList.length; i++) {
            mint(_toList[i], _amounts[i]);
        }
    }

    function batchBurn(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            burn(_userAddresses[i], _amounts[i]);
        }
    }

    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
        }
    }

    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            freezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external override onlyRole(AGENT_ROLE) returns (bool) {
        require(balanceOf(_lostWallet) != 0, "no tokens to recover");
        IIdentity _onchainID = IIdentity(_investorOnchainID);
        bytes32 _key = keccak256(abi.encode(_newWallet));
        if (_onchainID.keyHasPurpose(_key, 1)) {
            uint256 investorTokens = balanceOf(_lostWallet);
            uint256 frozenTokens = _frozenTokens[_lostWallet];
            _tokenIdentityRegistry.registerIdentity(
                _newWallet,
                _onchainID,
                _tokenIdentityRegistry.investorCountry(_lostWallet)
            );
            forcedTransfer(_lostWallet, _newWallet, investorTokens);
            if (frozenTokens > 0) {
                freezePartialTokens(_newWallet, frozenTokens);
            }
            if (_frozen[_lostWallet] == true) {
                setAddressFrozen(_newWallet, true);
            }
            _tokenIdentityRegistry.deleteIdentity(_lostWallet);
            emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
            return true;
        }
        revert("Recovery not possible");
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function allowance(address _owner, address _spender)
        external
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[_owner][_spender];
    }

    function identityRegistry()
        external
        view
        override
        returns (IIdentityRegistry)
    {
        return _tokenIdentityRegistry;
    }

    function compliance() external view override returns (IModularCompliance) {
        return _tokenCompliance;
    }

    function paused() external view override returns (bool) {
        return _tokenPaused;
    }

    function isFrozen(address _userAddress)
        external
        view
        override
        returns (bool)
    {
        return _frozen[_userAddress];
    }

    function getFrozenTokens(address _userAddress)
        external
        view
        override
        returns (uint256)
    {
        return _frozenTokens[_userAddress];
    }

    function decimals() external view override returns (uint8) {
        return _tokenDecimals;
    }

    function name() external view override returns (string memory) {
        return _tokenName;
    }

    function onchainID() external view override returns (address) {
        return _tokenOnchainID;
    }

    function symbol() external view override returns (string memory) {
        return _tokenSymbol;
    }

    function version() external pure override returns (string memory) {
        return _TOKEN_VERSION;
    }

    function transfer(address _to, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(!_frozen[_to] && !_frozen[msg.sender], "wallet is frozen");
        require(
            _amount <= balanceOf(msg.sender) - (_frozenTokens[msg.sender]),
            "Insufficient Balance"
        );
        if (
            _tokenIdentityRegistry.isVerified(_to) &&
            _tokenCompliance.canTransfer(msg.sender, _to, _amount)
        ) {
            _transfer(msg.sender, _to, _amount);
            _tokenCompliance.transferred(msg.sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public override onlyRole(AGENT_ROLE) returns (bool) {
        require(balanceOf(_from) >= _amount, "sender balance too low");
        uint256 freeBalance = balanceOf(_from) - (_frozenTokens[_from]);
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - (freeBalance);
            _frozenTokens[_from] = _frozenTokens[_from] - (tokensToUnfreeze);
            emit TokensUnfrozen(_from, tokensToUnfreeze);
        }
        if (_tokenIdentityRegistry.isVerified(_to)) {
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    function mint(address _to, uint256 _amount)
        public
        override
        onlyRole(AGENT_ROLE)
    {
        require(_totalSupply < maxsupply, "exceed");
        require(transcationdata[owner()][_to], "not paid by user");
        require(
            _tokenIdentityRegistry.isVerified(_to),
            "Identity is not verified."
        );
        require(
            _tokenCompliance.canTransfer(address(0), _to, _amount),
            "Compliance not followed"
        );
        _mint(_to, _amount);
        _tokenCompliance.created(_to, _amount);
        transcationdata[owner()][_to] = false;
    }

    function burn(address _userAddress, uint256 _amount)
        public
        override
        onlyRole(AGENT_ROLE)
    {
        require(
            balanceOf(_userAddress) >= _amount,
            "cannot burn more than balance"
        );
        uint256 freeBalance = balanceOf(_userAddress) -
            _frozenTokens[_userAddress];
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - (freeBalance);
            _frozenTokens[_userAddress] =
                _frozenTokens[_userAddress] -
                (tokensToUnfreeze);
            emit TokensUnfrozen(_userAddress, tokensToUnfreeze);
        }
        _burn(_userAddress, _amount);
        _tokenCompliance.destroyed(_userAddress, _amount);
    }

    function setAddressFrozen(address _userAddress, bool _freeze)
        public
        override
        onlyRole(AGENT_ROLE)
    {
        _frozen[_userAddress] = _freeze;

        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    function freezePartialTokens(address _userAddress, uint256 _amount)
        public
        override
        onlyRole(AGENT_ROLE)
    {
        uint256 balance = balanceOf(_userAddress);
        require(
            balance >= _frozenTokens[_userAddress] + _amount,
            "Amount exceeds available balance"
        );
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] + (_amount);
        emit TokensFrozen(_userAddress, _amount);
    }

    function unfreezePartialTokens(address _userAddress, uint256 _amount)
        public
        override
        onlyRole(AGENT_ROLE)
    {
        require(
            _frozenTokens[_userAddress] >= _amount,
            "Amount should be less than or equal to frozen tokens"
        );
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (_amount);
        emit TokensUnfrozen(_userAddress, _amount);
    }

    function setIdentityRegistry(address _identityRegistry)
        public
        onlyRole(OWNER_ROLE)
    {
        _tokenIdentityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryAdded(_identityRegistry);
    }

    function setCompliance(address _compliance) public onlyRole(OWNER_ROLE) {
        if (address(_tokenCompliance) != address(0)) {
            _tokenCompliance.unbindToken(address(this));
        }
        _tokenCompliance = IModularCompliance(_compliance);
        _tokenCompliance.bindToken(address(this));
        emit ComplianceAdded(_compliance);
    }

    function balanceOf(address _userAddress)
        public
        view
        override
        returns (uint256)
    {
        return _balances[_userAddress];
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(_from, _to, _amount);

        _balances[_from] = _balances[_from] - _amount;
        _balances[_to] = _balances[_to] + _amount;
        emit Transfer(_from, _to, _amount);
    }

    function _mint(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), _userAddress, _amount);

        _totalSupply = _totalSupply + _amount;
        _balances[_userAddress] = _balances[_userAddress] + _amount;
        emit Transfer(address(0), _userAddress, _amount);
    }

    function _burn(address _userAddress, uint256 _amount) internal virtual {
        require(
            _userAddress != address(0),
            "ERC20: burn from the zero address"
        );

        _beforeTokenTransfer(_userAddress, address(0), _amount);

        _balances[_userAddress] = _balances[_userAddress] - _amount;
        _totalSupply = _totalSupply - _amount;
        emit Transfer(_userAddress, address(0), _amount);
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual {}
}
