// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract rLiblock is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    ERC20Votes
{
    address internal admin;
    uint256 public maxSupply;

    constructor() ERC20("rLiblock", "rLIB") ERC20Permit("rLiblock") {
        admin = address(msg.sender);
        maxSupply = 150000000 * 10**decimals();
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not admin");
        _;
    }

    function setAdmin(address account) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(account != address(this), "Invalid address");
        admin = account;
    }

    function isAdmin(address account) private view returns (bool) {
        return admin == account;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function mint(address to, uint256 amount) external onlyAdmin {
        require(totalSupply() + amount >= maxSupply);
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external onlyAdmin {
        _burn(account, amount);
    }

    function delegateFrom(address delegator, address delegatee) external onlyAdmin {
        require(delegator != address(0), "Delegator can't be zero address");
        require(delegator != address(this), "Illegal");
        super._delegate(delegator, delegatee);
    }

    function selfApprove(uint amount) external onlyAdmin {
        _approve(address(this), address(admin), amount);
    }
}