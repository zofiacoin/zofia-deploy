// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ZOFIA is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    Ownable,
    ERC20Permit,
    ERC20Votes,
    ERC20FlashMint,
    Pausable,
    ReentrancyGuard,
    AccessControl
{
    // ==================== CONSTANTS ====================
    uint256 public constant MAX_SUPPLY = 100_000_000_000_000 * 10 ** 18;
    uint256 public constant AUTO_BURN_PERCENT = 100; // 1% (100 basis points)
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant VESTING_DURATION = 24 * 30 days; // 24 months
    uint256 public constant VESTING_CLIFF = 6 * 30 days; // 6 months cliff
    uint256 public constant TIMELOCK_DELAY = 48 hours;

    // ==================== STATE VARIABLES ====================
    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _excludedFromAutoBurn;
    uint256 public totalBurned;
    uint256 public totalVested;
    address public timelockController;

    // ==================== EVENTS ====================
    event BlacklistUpdated(address indexed account, bool status);
    event AutoBurnExclusionUpdated(address indexed account, bool status);
    event Burned(address indexed from, uint256 amount);
    event VestingCreated(address indexed beneficiary, uint256 amount);

    // ==================== MODIFIERS ====================
    modifier notBlacklisted(address account) {
        require(!_blacklist[account], "Address is blacklisted");
        _;
    }

    modifier onlyTimelockOrOwner() {
        require(msg.sender == timelockController || msg.sender == owner(), "Not authorized");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    constructor(
        address timelock,
        address multisigOwner
    )
        ERC20("zooq official", "ZOFIA")
        ERC20Permit("zooq official")
    {
        require(timelock != address(0) && multisigOwner != address(0), "Invalid addresses");

        // إعداد الحوكمة مع Timelock
        timelockController = timelock;

        // نقل الملكية إلى Multi‑Sig
        transferOwnership(multisigOwner);

        // منح صلاحيات إضافية لـ Timelock
        _grantRole(DEFAULT_ADMIN_ROLE, timelock);
        _grantRole(DEFAULT_ADMIN_ROLE, multisigOwner);
    }

    // ==================== MINTING ====================
    function mintForMigration(address to, uint256 amount)
        external
        onlyTimelockOrOwner
        nonReentrant
        whenNotPaused
    {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");

        _mint(to, amount);
        emit VestingCreated(to, amount);
    }

    // ==================== AUTO‑BURN ====================
    function _transfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
    {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");

        uint256 burnAmount = 0;
        if (!_excludedFromAutoBurn[from] && !_excludedFromAutoBurn[to]) {
            burnAmount = (amount * AUTO_BURN_PERCENT) / BASIS_POINTS;
            if (burnAmount > 0) {
                super._burn(from, burnAmount);
                totalBurned += burnAmount;
                emit Burned(from, burnAmount);
            }
        }

        uint256 transferAmount = amount - burnAmount;
        super._transfer(from, to, transferAmount);
    }

    // ==================== BLACKLIST ====================
    function setBlacklist(address account, bool status)
        external
        onlyTimelockOrOwner
    {
        require(account != address(0), "Invalid address");
        _blacklist[account] = status;
        emit BlacklistUpdated(account, status);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    // ==================== AUTO‑BURN EXCLUSION ====================
    function setAutoBurnExclusion(address account, bool status)
        external
        onlyTimelockOrOwner
    {
        require(account != address(0), "Invalid address");
        _excludedFromAutoBurn[account] = status;
        emit AutoBurnExclusionUpdated(account, status);
    }

    // ==================== PAUSABLE ====================
    function pause() external onlyTimelockOrOwner {
        _pause();
    }

    function unpause() external onlyTimelockOrOwner {
        _unpause();
    }

    // ==================== SNAPSHOT ====================
    function snapshot() external onlyTimelockOrOwner {
        _snapshot();
    }

    // ==================== INTERNAL OVERRIDES ====================
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Snapshot)
        whenNotPaused
        notBlacklisted(from)
        notBlacklisted(to)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
        totalBurned += amount;
        emit Burned(account, amount);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // ==================== TIMELOCK MANAGEMENT ====================
    function setTimelock(address newTimelock) external onlyOwner {
        require(newTimelock != address(0), "Invalid address");
        timelockController = newTimelock;
        _revokeRole(DEFAULT_ADMIN_ROLE, timelockController);
        _grantRole(DEFAULT_ADMIN_ROLE, newTimelock);
    }

    // ==================== BURN (User‑Initiated) ====================
    function burn(uint256 amount) public override {
        super.burn(amount);
        totalBurned += amount;
        emit Burned(_msgSender(), amount);
    }

    // ==================== VIEW FUNCTIONS ====================
    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    function getRemainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
