// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title rLiblock Token
 * @dev ERC20 token implementation with additional features.
 */
contract rLiblock is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
    address internal admin;
    uint256 public immutable maxSupply;

    event TokensMinted(address indexed to, uint256 indexed amount);
    event TokensBurned(address indexed from, uint256 indexed amount);

    /**
     * @dev Initializes the rLiblock token contract.
     */
    constructor() ERC20("rLiblock", "rLIB") ERC20Permit("rLiblock") {
        admin = address(msg.sender);
        maxSupply = 150000000 * 10 ** decimals();
    }

    /**
     * @dev Modifier to restrict access to admin-only functions.
     */
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not admin");
        _;
    }

    /**
     * @dev Sets a new admin address.
     * @param account The address to set as the admin.
     */
    function setAdmin(address account) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(account != address(this), "Invalid address");
        admin = account;
    }

    /**
     * @dev Checks if the given address is the admin.
     * @param account The address to check.
     * @return Whether the address is the admin or not.
     */
    function isAdmin(address account) public view returns (bool) {
        return admin == account;
    }

    /**
     * @dev Hook function called after any token transfer.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of tokens transferred.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    // overwrite required
    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // overwrite required
    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
        emit TokensBurned(account, amount);
    }

    /**
     * @dev Mints new tokens and assigns them to the specified address.
     * Only the admin can call this function.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyAdmin {
        require(
            totalSupply() + amount <= maxSupply,
            "Can not mint new rLIB for now"
        );
        _mint(to, amount);
    }

    /**
     * @dev Burns a specified amount of tokens from the given account.
     * Only the admin can call this function.
     * @param account The account from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address account, uint256 amount) external onlyAdmin {
        _burn(account, amount);
    }

    /**
     * @dev Delegates voting power from a delegator to a delegatee.
     * Only the admin can call this function.
     * @param delegator The address to delegate voting power from.
     * @param delegatee The address to delegate voting power to.
     */
    function delegateFrom(
        address delegator,
        address delegatee
    ) external onlyAdmin {
        require(delegator != address(0), "Delegator can't be zero address");
        require(delegator != address(this), "Illegal");
        super._delegate(delegator, delegatee);
    }

    /**
     * @dev Approves a spender to spend a specified amount of tokens on behalf of the contract itself.
     * Only the admin can call this function.
     * @param amount The amount of tokens to approve.
     */
    function selfApprove(uint256 amount) external onlyAdmin {
        _approve(address(this), address(admin), amount);
    }
}