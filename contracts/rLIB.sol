// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Liblock is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    ERC20Votes
{
    constructor() ERC20("Liblock reward", "rLIB") ERC20Permit("Liblock") {
        _mint(address(this), 150000000 * 10**decimals());
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
}