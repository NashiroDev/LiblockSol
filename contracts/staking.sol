// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./liblock.sol";


interface IERC20Wrapper is IERC20 {
    function wrappedToken() external view returns (IERC20);
}

abstract contract TokenStaking is IERC20Wrapper  {
    ERC20Wrapper private _wrapper;

    IERC20 private immutable depositToken;
    IERC20 private immutable rewardToken;
    uint256 private immutable dTokenRTokenRatio;

    event TokensLocked(address indexed user, uint amount);
    event TokensWithdrawn(address indexed user, uint amount);

    mapping(address => mapping(uint => Ledger)) private ledger;
    mapping(address => uint) private nounce;

    // mapping(address => mapping(uint => uint)) private locks;
    // mapping(address => mapping(uint => uint)) private lockPeriod;
    mapping(address => TokenTimelock) private _locks;

    struct Ledger {
        uint id;
        uint amountDeposited;
        uint amountIssued;
        uint8 ratio;
        uint lockUntil;
    }

    constructor(
        address _depositToken,
        address _rewardToken,
        uint256 _dTokenRTokenRatio
    ) {
        depositToken = IERC20(_depositToken);
        rewardToken = IERC20(_rewardToken);
        dTokenRTokenRatio = _dTokenRTokenRatio;
    }

    function lockTokens(uint256 amount, uint8 ratio, uint32 lockDuration) private {
        require(amount > 0, "Amount must be greater than zero");

        depositToken.transferFrom(msg.sender, address(this), amount);

        uint256 rewardAmount = amount * ratio;
        rewardToken.transferFrom(address(this), msg.sender, rewardAmount);

        TokenTimelock lock = new TokenTimelock(depositToken, msg.sender, block.timestamp + lockDuration);

        _locks[msg.sender] = lock;

        ledger[msg.sender][nounce[msg.sender]] = Ledger(
            nounce[msg.sender],
            amount,
            rewardAmount,
            ratio,
            block.timestamp + lockDuration
        );

        nounce[msg.sender] += 1;
        emit TokensLocked(msg.sender, amount);
    }

    // function withdrawTokens() external {
    //     TokenTimelock lock = _locks[msg.sender];
    //     require(address(lock) != address(0), "No tokens locked for the user");

    //     require(lock.isLocked(), "Tokens are not yet unlocked");

    //     uint256 depositAmount = _deposits[msg.sender];
    //     uint256 rewardAmount = _rewardTokensIssued[msg.sender];

    //     delete _locks[msg.sender];
    //     delete _deposits[msg.sender];
    //     delete _rewardTokensIssued[msg.sender];

    //     _token.safeTransfer(msg.sender, depositAmount);
    //     _rewardToken.safeTransfer(msg.sender, rewardAmount);

    //     emit TokensWithdrawn(msg.sender, depositAmount);
    // }

    function getDeposits(address user, uint id) external view returns (Ledger memory) {
        return ledger[user][id];
    }
}