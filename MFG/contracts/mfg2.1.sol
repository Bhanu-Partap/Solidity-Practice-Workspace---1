// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MFGToken1 is ERC20PermitUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    address public governance;
    // The timestamp after which minting may occur
    uint256 public mintAllowedAfter;
    // The timestamp after which burning may occur
    uint256 public burnAllowedAfter;
    bool Freeze;
    // Minimum time between mints/burns
    uint32 public constant minimumTime = 1 days * 365;
    address locker;
    // Cap on the percentage of totalSupply that can be minted/burned at each mint/burn
    uint8 public constant cap = 2;
    uint256 public sum ;
    event GovernanceChanged(
        address indexed oldGovernance,
        address indexed newGovernance
    );

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 allowedAfter,
        address _governance,
        address account
    ) public initializer  // ERC20(name, symbol)
    // ERC20Permit(name)
    {
        __ERC20Permit_init(name);
        __ERC20_init(name, symbol);
        __Ownable_init(_governance); // Initializes the Ownable
        __UUPSUpgradeable_init(); // Initializes UUPS proxy
        require(
            allowedAfter >= 0,
            "Minting/Burning can only begin after deployment"
        );
        mintAllowedAfter = block.timestamp + allowedAfter;
        burnAllowedAfter = block.timestamp + allowedAfter;
        governance = _governance;
        Freeze=false;
        _mint(account, initialSupply);
    }

    function cal(uint256 a, uint256 b) public  returns(uint256){
        sum = a+b;
        return sum;
    }

    modifier isFreezed() {
        require(Freeze != true, "all actions Freezed, please wait");
        _;
    }

    /**
     * @notice Change the governance address
     * @param _governance The address of the new governance
     */
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "Unauthorised access");
        emit GovernanceChanged(governance, _governance);
        governance = _governance;
    }

    /**
     * @notice Mint new tokens
     * @param receiver The address of the destination account
     * @param amount The number of tokens to be minted
     */
    function mint(address receiver, uint256 amount) external isFreezed {
        require(msg.sender == governance, "Unauthorized access");
        // require(block.timestamp >= mintAllowedAfter, "minting not allowed yet");
        require(receiver != address(0), "cannot transfer to the zero address");

        // record the mint
        mintAllowedAfter = block.timestamp + minimumTime;

        // mint the amount
        require(amount <= ((totalSupply() * cap)/100), "exceeded mint cap");
        _mint(receiver, amount);
    }

    function FreezeAll(bool action) public returns (bool) {
        require(msg.sender == governance, "Unauthorised access");
        Freeze = action;
        return Freeze;
    }

    // /**
    //  * @notice Burn tokens
    //  * @param amount The number of tokens to be burned
    //  * Tokens will be burned from governance account
    //  */
    // function burn(uint256 amount) external isFreezed {
    //     require(msg.sender == governance, "Unauthorized access");
    //     // require(block.timestamp >= burnAllowedAfter, "burning not allowed yet");

    //     // record the mint
    //     burnAllowedAfter = block.timestamp + minimumTime;

    //     // mint the amount
    //     require(amount <= ((totalSupply() * cap)/100), "exceeded burn cap");
    //     _burn(governance, amount);
    // }

    function approve(address spender, uint256 value)
        public
        virtual
        override
        isFreezed
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override isFreezed returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value)
        public
        virtual
        override
        isFreezed
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function setLocker(address contractLocker) public returns (string memory){
        require(locker == address(0),"Locker is already deployer");
        locker = contractLocker;
        return "success";
    }

     // Authorize the upgrade to the new implementation (only governance or owner can upgrade)
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
