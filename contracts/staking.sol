// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LIB.sol";
import "./rLIB.sol";


contract TokenStaking {

    Liblock private immutable depositToken;
    rLiblock private immutable rewardToken;

    event TokensLocked(address indexed user, uint amount);
    event TokensWithdrawn(address indexed user, uint amount);

    mapping(address => mapping(uint => Ledger)) public ledger;
    mapping(address => uint) public nounce;

    struct Ledger {
        uint id;
        uint amountDeposited;
        uint amountIssued;
        uint8 ratio;
        uint lockUntil;
        TokenTimelock lock;
    }

    constructor(
        address _depositToken,
        address _rewardToken
    ) {
        depositToken = Liblock(_depositToken);
        rewardToken = rLiblock(_rewardToken);
    }

    function lockTokens(uint256 amount, uint8 ratio, uint32 lockDuration) external {
        require(amount > 0, "Amount must be greater than zero");

        uint256 rewardAmount = amount * ratio;

        TokenTimelock lock = new TokenTimelock(depositToken, msg.sender, block.timestamp + lockDuration);

        depositToken.transferFrom(msg.sender, address(lock), amount);
        rewardToken.transferFrom(address(rewardToken), msg.sender, rewardAmount);

        ledger[msg.sender][nounce[msg.sender]] = Ledger(
            nounce[msg.sender],
            amount,
            rewardAmount,
            ratio,
            block.timestamp + lockDuration,
            lock
        );

        nounce[msg.sender] += 1;
        emit TokensLocked(msg.sender, amount);
    }

    function withdrawTokens(uint id) external {
        TokenTimelock lock = ledger[msg.sender][id].lock;
        uint amountIssued = ledger[msg.sender][id].amountIssued;

        require(rewardToken.allowance(msg.sender, address(this)) >= amountIssued, "Not enough rLIB allowance");
        require(rewardToken.balanceOf(msg.sender) >= amountIssued, "Not enough rLIB to withdraw");
        require(address(lock) != address(0), "No tokens locked for the user");

        lock.release();
        rewardToken.transferFrom(msg.sender, address(this), amountIssued);

        delete ledger[msg.sender][id];
        nounce[msg.sender] -= 1;

        emit TokensWithdrawn(msg.sender, amountIssued);
    }

    function approveDepositToken(address spender, uint amount) external {
        depositToken.approve(spender, amount);
    }

    function approveRewardToken(address spender, uint amount) external {
        rewardToken.approve(spender, amount);
    }

    function requestAllowance(uint amount) private {
        rewardToken.selfApprove(amount);
    }
}