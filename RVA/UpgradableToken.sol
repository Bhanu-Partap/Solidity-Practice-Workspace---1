// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract ERC20Token is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    address public icoContract;
    uint256 private _totalSupply;
    using AddressUpgradeable for address;

    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public lockedUntil;
    mapping(address => uint256) public lockedAmount;

    event ICOContractSet(address indexed icoContract);
    event LockupSet(address indexed account, uint256 lockedUntilTimestamp, uint256 lockedAmount);
    event Blacklisted(address indexed account, bool isBlacklisted);
    event EmergencyTokenRecovered(address indexed token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Disables constructors for upgradeable contracts.
    }

    function initialize(string memory name, string memory symbol, uint256 totalSupply_) external initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();

        _totalSupply = totalSupply_;
        _mint(msg.sender, _totalSupply); // Mint initial supply to the deployer
    }

    modifier onlyICOContract() {
        require(msg.sender == icoContract, "Not authorized");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setLockup(address account, uint256 timestamp, uint256 amount) external whenNotPaused onlyICOContract  {
    require(account != address(0), "Null Address");
    require(amount != 0, "Amount must be greater than zero");
   
    if (lockedUntil[account] != timestamp || lockedAmount[account] != amount) {
        lockedUntil[account] = timestamp;
        lockedAmount[account] = amount;  
        emit LockupSet(account, timestamp, amount);
    }
}

    function setBlacklist(address account, bool status) external onlyOwner {
        require(account !=address(0),"Null Address");
        blacklisted[account] = status;
        emit Blacklisted(account, status);
    }

    // function isBlacklisted(address account) public view returns (bool) {
    //     return blacklisted[account];
    // }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!blacklisted[msg.sender], "Transfer failed: Sender is blacklisted");
        require(!blacklisted[recipient], "Transfer failed: Recipient is blacklisted");
        require(amount !=0,"Amount shouldn't be zero");
        require(block.timestamp >= lockedUntil[msg.sender] || lockedUntil[msg.sender] == 0, "Transfer failed: Tokens are locked");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!blacklisted[sender], "Transfer failed: Sender is blacklisted");
        require(!blacklisted[recipient], "Transfer failed: Recipient is blacklisted");
        require(amount !=0,"Amount shouldn't be zero");
        require(block.timestamp >= lockedUntil[sender] || lockedUntil[sender] == 0, "Transfer failed: Tokens are locked");
        return super.transferFrom(sender, recipient, amount);
    }

    function setICOContract(address _icoContract) external whenNotPaused onlyOwner  {
        require(_icoContract != address(0), "Null Address");
        require(_icoContract.isContract(), "Address is not a contract");
        icoContract = _icoContract;
        emit ICOContractSet(_icoContract);
    }

    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused {
        require(recipients.length == amounts.length, "BatchTransfer failed: Mismatched arrays");
        uint256 recipientLength = recipients.length;
        for (uint256 i = 0; i < recipientLength; i++) {
            unchecked{
                if (blacklisted[recipients[i]]) {
                    revert("BatchTransfer failed: Recipient is blacklisted");
                }
            _transfer(msg.sender, recipients[i], amounts[i]);
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override whenNotPaused onlyOwner {}
}


    // RichmindVirtualAsset Token
    // RVA
    // 1500000000e18