// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Liblock is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
    // Init section

    address internal admin;

    // setting initial destination wallet address for fees
    address private devWallet =
        payable(0x05525CdE529C5212F1eaB7f033146C8CC103cd5D);
    address private distributionContract =
        payable(0x3a15BBaeCdBb123bd30583C6249D2d1dd13e0709);
    address private liblockFondationWallet;

    // setting initial shares of generated fees
    uint16 public devWalletShares = 100; //10%
    uint16 public distributionContractShares = 625; //62,5%
    uint16 public liblockFondationWalletShares = 200; //20%
    uint16 public zeroAddressShares = 75; //7.5%

    mapping(address => bool) public excludedFromFee;

    constructor() ERC20("Liblock", "LIB") ERC20Permit("Liblock") {
        _mint(address(this), 74500000 * 10 ** decimals());
        _mint(address(msg.sender), 500000 * 10 ** decimals());
        admin = address(msg.sender);
        liblockFondationWallet = admin;
        excludedFromFee[msg.sender] = true;
    }

    // admin related stuff

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

    // overwrite required function

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    // token exclusive function

    // Define the amout of fees a user will pay depending of the amount of token
    function calculateFeePercentage(
        uint256 amount
    ) private pure returns (uint32) {
        if (amount >= 35000000 * 10 ** 18) {
            return 520000000; // 52% fee
        } else if (amount >= 10000000 * 10 ** 18) {
            uint256 fee = ((amount - 10000000 * 10 ** 18) / 10 ** 18) * 8; // 0.0000008
            return uint32(320000000 + fee); // 32% fee + 8 / 10**7 per full token
        } else if (amount >= 1000000 * 10 ** 18) {
            uint256 fee = ((amount - 1000000 * 10 ** 18) / 10 ** 18) * 22; // 0.00000022
            return uint32(120000000 + fee); // 12% fee + 22 / 10**7 per full token
        } else if (amount >= 100000 * 10 ** 18) {
            uint256 fee = ((amount - 100000 * 10 ** 18) / 10 ** 18) * 83; // 0.0000083
            return uint32(45000000 + fee); // 4.5% fee + 83 / 10**7 per full token
        } else if (amount >= 10000 * 10 ** 18) {
            uint256 fee = ((amount - 10000 * 10 ** 18) / 10 ** 18) * 416; // 0.0000416
            return uint32(7500000 + fee); // 0.75% fee + 416 / 10**7 per full token
        } else if (amount >= 1000 * 10 ** 18) {
            uint256 fee = ((amount - 1000 * 10 ** 18) / 10 ** 18) * 500; // 0.00005
            return uint32(3000000 + fee); // 0.3% fee + 500 / 10**7 per full token
        } else if (amount >= 100 * 10 ** 18) {
            uint256 fee = ((amount - 100 * 10 ** 18) / 10 ** 18) * 2222; // 0.0002222
            return uint32(1000000 + fee); // 0.1% fee + 2222 / 10**7 per full token
        } else if (amount >= 10 * 10 ** 18) {
            uint256 fee = ((amount - 10 * 10 ** 18) / 10 ** 18) * 10000; // 0.001
            return uint32(100000 + fee); // 0.01% fee + 10000 / 10**7 per full token
        } else {
            return 100000; // 0.01% fee
        }
    }

    // Overwrite past recipients address and allocations
    function setFeeRecipientsAndShares(
        address _devWallet,
        uint16 _devWalletShares,
        address _distributionContract,
        uint16 _distributionContractShares,
        uint16 _liblockFondationWalletShares,
        uint16 _zeroAdressShares
    ) external onlyAdmin {
        require(
            _devWalletShares +
                _distributionContractShares +
                _liblockFondationWalletShares +
                _zeroAdressShares ==
                1000,
            "Cummulated shares not equal to 1000"
        );
        devWallet = _devWallet;
        distributionContract = _distributionContract;
        liblockFondationWallet = msg.sender;
        devWalletShares = _devWalletShares;
        distributionContractShares = _distributionContractShares;
        liblockFondationWalletShares = _liblockFondationWalletShares;
        zeroAddressShares = _zeroAdressShares;
    }

    // fees are currently applied to the transfer and tranferFrom function
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (excludedFromFee[sender] || excludedFromFee[recipient]) {
            super._transfer(sender, recipient, amount);
        } else {
            uint32 feePercentage = calculateFeePercentage(amount);
            require(feePercentage < 65 * 10 ** 7, "Max fee amount reached");
            uint256 feeAmount = (amount * (feePercentage / 10 ** 3)) / 10 ** 6;
            uint256 transferAmount = amount - feeAmount;

            super._transfer(sender, recipient, transferAmount);
            super._transfer(
                sender,
                devWallet,
                (feeAmount * devWalletShares) / 10 ** 3
            );
            super._transfer(
                sender,
                distributionContract,
                (feeAmount * distributionContractShares) / 10 ** 3
            );
            super._transfer(
                sender,
                liblockFondationWallet,
                (feeAmount * liblockFondationWalletShares) / 10 ** 3
            );
            super._burn(sender, (feeAmount * zeroAddressShares) / 10 ** 3);
        }
    }
}
