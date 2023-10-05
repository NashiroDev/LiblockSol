// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";


interface IERC20Wrapper is IERC20 {
    function wrappedToken() external view returns (IERC20);
}

abstract contract TokenStaking is IERC20Wrapper  {
    ERC20Wrapper private _wrapper;

    IERC20 private immutable _token;
    IERC20 private immutable _rewardToken;
    uint256 private immutable _rewardRatio;
    uint256 private immutable _lockDuration;

    mapping(address => uint256) private _deposits;
    mapping(address => TokenTimelock) private _locks;
    mapping(address => uint256) private _rewardTokensIssued;
    uint256 private _totalDeposits;
    uint256 private _totalRewardTokensIssued;

    event TokensLocked(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);

    constructor(
        address tokenAddress,
        address rewardTokenAddress,
        uint256 rewardRatio,
        uint256 lockDuration
    ) {
        _token = IERC20(tokenAddress);
        _rewardToken = IERC20(rewardTokenAddress);
        _rewardRatio = rewardRatio;
        _lockDuration = lockDuration;
    }

    function lockTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        _token.transferFrom(msg.sender, address(this), amount);

        uint256 rewardAmount = amount * _rewardRatio;
        _rewardToken.transferFrom(msg.sender, address(this), rewardAmount);

        _deposits[msg.sender] += amount;
        _totalDeposits += amount;
        _rewardTokensIssued[msg.sender] += rewardAmount;
        _totalRewardTokensIssued += rewardAmount;

        TokenTimelock lock = new TokenTimelock(_token, msg.sender, block.timestamp + _lockDuration);
        _locks[msg.sender] = lock;

        emit TokensLocked(msg.sender, amount);
    }

    function withdrawTokens() external {
        TokenTimelock lock = _locks[msg.sender];
        require(address(lock) != address(0), "No tokens locked for the user");

        require(lock.isLocked(), "Tokens are not yet unlocked");

        uint256 depositAmount = _deposits[msg.sender];
        uint256 rewardAmount = _rewardTokensIssued[msg.sender];

        delete _locks[msg.sender];
        delete _deposits[msg.sender];
        delete _rewardTokensIssued[msg.sender];

        _token.safeTransfer(msg.sender, depositAmount);
        _rewardToken.safeTransfer(msg.sender, rewardAmount);

        emit TokensWithdrawn(msg.sender, depositAmount);
    }

    function getTotalDeposits() external view returns (uint256) {
        return _totalDeposits;
    }

    function getDeposits(address user) external view returns (uint256) {
        return _deposits[user];
    }

    function getTotalRewardTokensIssued() external view returns (uint256) {
        return _totalRewardTokensIssued;
    }

    function getRewardTokensIssued(address user) external view returns (uint256) {
        return _rewardTokensIssued[user];
    }

    function getLockDuration() external view returns (uint256) {
        return _lockDuration;
    }
}