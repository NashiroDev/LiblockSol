// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Liblock is
    ERC20,
    ERC20Burnable,
    AccessControl,
    ERC20Permit,
    ERC20Votes
{
    constructor() ERC20("Liblock", "LIB") ERC20Permit("Liblock") {
        _mint(msg.sender, 1000 * 10**decimals());
        _mint(address(this), 64999000 * 10**decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // The following functions are overrides required by Solidity.

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

    /**
     * @dev Delegate votes from 'delegator' to `delegatee`.
     */
    function delegateFrom(address delegator, address delegatee) public virtual {
        _delegate(delegator, delegatee);
    }
}