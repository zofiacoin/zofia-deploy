// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract ZOFIA is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    Ownable,
    ERC20Permit,
    ERC20Votes,
    ERC20FlashMint
{
    uint256 public constant MAX_SUPPLY = 100_000_000_000_000 * 10 ** 18;

    constructor(address initialOwner)
        ERC20("zooq official", "ZOFIA")
        ERC20Permit("zooq official")
    {
        // نقل الملكية إلى العنوان المطلوب بعد النشر
        transferOwnership(initialOwner);
    }

    // دالة لإضافة رموز للهجرة (للاستدعاء من عقد الهجرة)
    function mintForMigration(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    // دالة لأخذ لقطة (snapshot) يدوياً
    function snapshot() external onlyOwner {
        _snapshot();
    }

    // ========== تجاوزات الدوال الأساسية للتعامل مع الـ Inheritance ==========

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        // استدعاء الدالة من ERC20 (فارغة) و ERC20Snapshot (تأخذ اللقطة)
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        // استدعاء الدالة من ERC20 (فارغة) و ERC20Votes (تحديث نقاط التصويت)
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        // استدعاء ERC20 و ERC20Votes لإتمام عملية السك
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        // استدعاء ERC20 و ERC20Votes لإتمام عملية الحرق
        super._burn(account, amount);
    }

    // ========== تجاوز دالة nonces لتجنب التعارض ==========

    function nonces(address owner)
        public
        view
        override(ERC20Permit)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
