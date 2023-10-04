// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract TokenX is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
    address public feeRecipient;
    address internal admin;

    constructor() ERC20("TokenX", "TOX") ERC20Permit("TokenX") {
        _mint(address(this), 75000000 * 10**decimals());
        _mint(address(msg.sender), 75000000 * 10**decimals());
        setAdmin(msg.sender);
        feeRecipient = address(this);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    function setAdmin(address account) private {
        require(account != address(0), "Invalid address");
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

    function calculateFeePercentage(uint256 amount)
        private
        pure
        returns (uint256)
    {
        if (amount >= 35000000 * 10**18) {
            return 520000000; // 52% fee
        } else if (amount >= 10000000 * 10**18) {
            uint fee = ((amount - 10000000 * 10**18) / 10**18) * 8; // 0.0000008
            return 320000000+fee; // 32% fee + 8 / 10**7 per full token
        } else if (amount >= 1000000 * 10**18) {
            uint fee = ((amount - 1000000 * 10**18) / 10**18) * 22; // 0.00000022
            return 120000000+fee; // 12% fee + 22 / 10**7 per full token
        } else if (amount >= 100000 * 10**18) {
            uint fee = ((amount - 100000 * 10**18) / 10**18) * 83; // 0.0000083
            return 45000000+fee; // 4.5% fee + 83 / 10**7 per full token
        } else if (amount >= 10000 * 10**18) {
            uint fee = ((amount - 10000 * 10**18) / 10**18) * 416; // 0.0000416
            return 7500000+fee; // 0.75% fee + 416 / 10**7 per full token
        } else if (amount >= 1000 * 10**18) {
            uint fee = ((amount - 1000 * 10**18) / 10**18) * 500; // 0.00005
            return 3000000+fee; // 0.3% fee + 500 / 10**7 per full token
        } else if (amount >= 100 * 10**18) {
            uint fee = ((amount - 100 * 10**18) / 10**18) * 2222; // 0.0002222
            return 1000000+fee; // 0.1% fee + 2222 / 10**7 per full token
        } else if (amount >= 10 * 10**18) {
            uint fee = ((amount - 10 * 10**18) / 10**18) * 10000; // 0.001
            return 100000+fee; // 0.01% fee + 10000 / 10**7 per full token
        } else {
            return 100000; // 0.01% fee
        }
    }

    function setFeeRecipient(address _feeRecipient) external onlyAdmin {
        feeRecipient = _feeRecipient;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 feePercentage = calculateFeePercentage(amount);
        require(feePercentage < 1000000, "Unreal fee amount");
        uint256 feeAmount = (amount * feePercentage) / 10**6;
        uint256 transferAmount = amount - feeAmount;

        super._transfer(sender, recipient, transferAmount);
        super._transfer(sender, feeRecipient, feeAmount);
    }
}
