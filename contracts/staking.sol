// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LIB.sol";
import "./rLIB.sol";


contract TokenStaking {

    Liblock private immutable depositToken;
    rLiblock private immutable rewardToken;
    uint public totalDepositedToken;
    uint public totalIssuedToken;

    event TokensLocked(address indexed user, uint amount);
    event TokensWithdrawn(address indexed user, uint amount);

    mapping(address => mapping(uint => Ledger)) public ledger;
    mapping(address => uint) public nounce;

    struct Ledger {
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
        totalDepositedToken = 0;
        totalIssuedToken = 0;
    }

    function lock17(uint amount) external {
        lockTokens(amount, 100, 17 days);
    }

    function lock31(uint amount) external {
        lockTokens(amount, 105, 31 days);
    }

    function lock93(uint amount) external {
        lockTokens(amount, 125, 93 days);
    }

    function lock186(uint amount) external {
        lockTokens(amount, 145, 186 days);
    }

    function lock279(uint amount) external {
        lockTokens(amount, 160, 279 days);
    }

    function lock365(uint amount) external {
        lockTokens(amount, 170, 365 days);
    }

    function lockTokens(uint256 amount, uint8 ratio, uint32 lockDuration) private {
        require(amount > 0, "Amount must be greater than zero");

        uint256 rewardAmount = amount * (ratio / 10**2);
        require(rewardAmount <= rewardToken.balanceOf(address(rewardToken)), "Not enough rLIB available");

        TokenTimelock lock = new TokenTimelock(depositToken, msg.sender, block.timestamp + lockDuration);

        // requestAllowance(rewardAmount);
        requestNewFeeExcludedAddress(address(lock), true);

        depositToken.transferFrom(msg.sender, address(lock), amount);
        // rewardToken.transferFrom(address(rewardToken), msg.sender, rewardAmount);
        requestMint(rewardAmount);

        requestDelegationDeposit(address(lock), msg.sender);
        requestDelegationReward(msg.sender, msg.sender);

        ledger[msg.sender][nounce[msg.sender]] = Ledger(
            amount,
            rewardAmount,
            ratio,
            block.timestamp + lockDuration,
            lock
        );

        nounce[msg.sender]++;
        totalDepositedToken += amount;
        totalIssuedToken += rewardAmount;

        emit TokensLocked(msg.sender, amount);
    }

    function withdrawTokens(uint id) external {
        TokenTimelock lock = ledger[msg.sender][id].lock;
        uint amountIssued = ledger[msg.sender][id].amountIssued;
        uint amountDeposited = ledger[msg.sender][id].amountDeposited;

        require(rewardToken.allowance(msg.sender, address(this)) >= amountIssued, "Not enough rLIB allowance");
        require(rewardToken.balanceOf(msg.sender) >= amountIssued, "Not enough rLIB to withdraw");
        require(address(lock) != address(0), "No tokens locked for this identifier");

        lock.release();
        requestBurn(amountIssued);
        // rewardToken.transferFrom(msg.sender, address(rewardToken), amountIssued);

        delete ledger[msg.sender][id];
        requestNewFeeExcludedAddress(address(lock), false);
        requestDelegationDeposit(msg.sender, msg.sender);

        nounce[msg.sender]--;
        totalDepositedToken -= amountDeposited;
        totalIssuedToken -= amountIssued;

        emit TokensWithdrawn(msg.sender, amountIssued);
    }

    // get the lock time remaining in seconds
    function getLockTimeRemaining(address _address, uint _nounce) external view returns(uint timeRemaining) {
        return ledger[_address][_nounce].lockUntil - block.timestamp;
    }

    // function requestAllowance(uint amount) private {
    //     rewardToken.selfApprove(amount);
    // }

    function requestNewFeeExcludedAddress(address _address, bool _excluded) private {
        depositToken.setFeeExcludedAddress(_address, _excluded);
    }

    function requestDelegationDeposit(address delegator, address delegatee) private {
        depositToken.delegateFrom(delegator, delegatee);
    }

    function requestDelegationReward(address delegator, address delegatee) private {
        rewardToken.delegateFrom(delegator, delegatee);
    }

    function requestMint(uint amount) private {
        rewardToken.mint(msg.sender, amount);
    }

    function requestBurn(uint amount) private {
        rewardToken.burn(msg.sender, amount);
    }
}