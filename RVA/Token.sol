// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract erc20Token is ERC20, Ownable, Pausable {

    address public icoContract;
    uint256 private _totalSupply = 1000000 * 10 ** 18; 

    mapping(address => uint256) public lockedUntil; 
    mapping(address => bool) public blacklisted;  


    event ICOContractSet(address indexed icoContract);
    event LockupSet(address indexed account, uint256 lockedUntilTimestamp);
    event Blacklisted(address indexed account, bool isBlacklisted);
    event EmergencyTokenRecovered(address indexed token, uint256 amount);

    constructor(string memory name, string memory symbol) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, _totalSupply); 
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

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function setLockup(address account, uint256 timestamp) external onlyICOContract {
        lockedUntil[account] = timestamp;
        emit LockupSet(account, timestamp);
    }
    

    function setBlacklist(address account, bool status) external onlyOwner {
        blacklisted[account] = status;
        emit Blacklisted(account, status);
    }

    function isBlacklisted(address account) public view returns (bool) {
        return blacklisted[account];
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!blacklisted[msg.sender], "Transfer failed: Sender is blacklisted");
        require(!blacklisted[recipient], "Transfer failed: Recipient is blacklisted");
        require(block.timestamp >= lockedUntil[msg.sender] || lockedUntil[msg.sender] == 0, "Transfer failed: Tokens are locked");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(!blacklisted[sender], "Transfer failed: Sender is blacklisted");
        require(!blacklisted[recipient], "Transfer failed: Recipient is blacklisted");
        require(block.timestamp >= lockedUntil[sender] || lockedUntil[sender] == 0, "Transfer failed: Tokens are locked");
        return super.transferFrom(sender, recipient, amount);
    }

    function setICOContract(address _icoContract) external onlyOwner {
        icoContract = _icoContract;
        emit ICOContractSet(_icoContract);
    }

    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused {
        require(recipients.length == amounts.length, "BatchTransfer failed: Mismatched arrays");
        uint256 recipientLength = recipients.length;
        for (uint256 i = 0; i < recipientLength; i++) {
            require(!blacklisted[recipients[i]], "BatchTransfer failed: Recipient is blacklisted");
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

}