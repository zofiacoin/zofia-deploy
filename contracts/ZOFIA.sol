// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ZOFIA is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    Ownable2Step,
    ERC20Permit,
    ERC20Votes,
    Pausable
{
    uint256 public constant MAX_SUPPLY = 100_000_000_000_000 * 10 ** 18;

    mapping(address => bool) private _blacklist;

    event BlacklistUpdated(address indexed account, bool status);
    event MintedForMigration(address indexed to, uint256 amount);

    modifier notBlacklisted(address account) {
        require(!_blacklist[account], "Address is blacklisted");
        _;
    }

    // ==================== CONSTRUCTOR ====================
    constructor()
        ERC20("zooq official", "ZOFIA")
        ERC20Permit("zooq official")
    {
        // المالك هو عنوان الناشر (msg.sender)
        _transferOwnership(msg.sender);
    }

    // ==================== MINTING ====================
    function mintForMigration(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        emit MintedForMigration(to, amount);
    }

    // ==================== TRANSFER with Blacklist ====================
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
        super._transfer(from, to, amount);
    }

    // ==================== BLACKLIST ====================
    function setBlacklist(address account, bool status) external onlyOwner {
        _blacklist[account] = status;
        emit BlacklistUpdated(account, status);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    // ==================== PAUSABLE ====================
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================== SNAPSHOT ====================
    function snapshot() external onlyOwner {
        _snapshot();
    }

    // ==================== OVERRIDES ====================
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
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
