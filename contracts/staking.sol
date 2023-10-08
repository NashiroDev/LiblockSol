// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LIB.sol";
import "./rLIB.sol";
import "./distribute.sol";

contract TokenStaking {
    Liblock private immutable depositToken;
    rLiblock private immutable rewardToken;
    Distributor private immutable shareDistributionContract;

    uint private totalDepositedToken;
    uint private totalIssuedToken;

    event TokensLocked(address indexed user, uint amount);
    event TokensWithdrawn(address indexed user, uint amount);

    mapping(address => mapping(uint => Ledger)) public ledger;
    mapping(address => uint) private nounce;

    struct Ledger {
        uint amountDeposited;
        uint amountIssued;
        uint8 ratio;
        uint lockedAt;
        uint lockUntil;
        TokenTimelock lock;
    }

    constructor(
        address _depositToken,
        address _rewardToken,
        address _shareDistributionContract
    ) {
        depositToken = Liblock(_depositToken);
        rewardToken = rLiblock(_rewardToken);
        shareDistributionContract = Distributor(_shareDistributionContract);
        totalDepositedToken = 0;
        totalIssuedToken = 0;
    }

    function lock17(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 100, 17 days);
    }

    function lock31(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 105, 31 days);
    }

    function lock93(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 125, 93 days);
    }

    function lock186(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 145, 186 days);
    }

    function lock279(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 160, 279 days);
    }

    function lock365(uint amount) external {
        require(
            amount <= depositToken.balanceOf(msg.sender),
            "Not enough tokens"
        );
        lockTokens(amount, 170, 365 days);
    }

    function lockTokens(
        uint256 amount,
        uint8 ratio,
        uint32 lockDuration
    ) private {
        require(amount > 0, "Amount must be greater than zero");
        require(ratio <= 200, "Ratio is too high");
        require(
            depositToken.allowance(msg.sender, address(this)) >= amount,
            "Not enough LIB allowance"
        );

        uint256 rewardAmount = (amount * ratio) / 10 ** 2;

        TokenTimelock lock = new TokenTimelock(
            depositToken,
            msg.sender,
            block.timestamp + lockDuration
        );

        requestNewFeeExcludedAddress(address(lock), true);

        depositToken.transferFrom(msg.sender, address(lock), amount);
        requestMint(rewardAmount);

        requestDelegationDeposit(address(lock), msg.sender);
        requestDelegationReward(msg.sender, msg.sender);

        ledger[msg.sender][nounce[msg.sender]] = Ledger(
            amount,
            rewardAmount,
            ratio,
            block.timestamp,
            block.timestamp + lockDuration,
            lock
        );

        sendSharesData(
            msg.sender,
            nounce[msg.sender],
            rewardAmount,
            ledger[msg.sender][nounce[msg.sender]].lockedAt,
            ledger[msg.sender][nounce[msg.sender]].lockUntil
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

        require(
            rewardToken.allowance(msg.sender, address(this)) >= amountIssued,
            "Not enough rLIB allowance"
        );
        require(
            rewardToken.balanceOf(msg.sender) >= amountIssued,
            "Not enough rLIB to withdraw"
        );
        require(
            address(lock) != address(0),
            "No tokens locked for this identifier"
        );

        lock.release();
        requestBurn(amountIssued);

        delete ledger[msg.sender][id];
        requestNewFeeExcludedAddress(address(lock), false);
        requestDelegationDeposit(msg.sender, msg.sender);

        nounce[msg.sender]--;
        totalDepositedToken -= amountDeposited;
        totalIssuedToken -= amountIssued;

        emit TokensWithdrawn(msg.sender, amountIssued);
    }

    // get the lock time remaining in seconds
    function getLockTimeRemaining(
        address _address,
        uint _nounce
    ) external view returns (uint) {
        require(
            _nounce <= nounce[_address],
            "This nounce do not exist for this address"
        );
        return ledger[_address][_nounce].lockUntil - block.timestamp;
    }

    function requestNewFeeExcludedAddress(
        address _address,
        bool _excluded
    ) private {
        depositToken.setFeeExcludedAddress(_address, _excluded);
    }

    function requestDelegationDeposit(
        address delegator,
        address delegatee
    ) private {
        depositToken.delegateFrom(delegator, delegatee);
    }

    function requestDelegationReward(
        address delegator,
        address delegatee
    ) private {
        rewardToken.delegateFrom(delegator, delegatee);
    }

    function requestMint(uint amount) private {
        rewardToken.mint(msg.sender, amount);
    }

    function requestBurn(uint amount) private {
        rewardToken.burn(msg.sender, amount);
    }

    function sendSharesData(
        address _address,
        uint _nounce,
        uint amount,
        uint lockTimestamp,
        uint unlockTimestamp
    ) private {
        require(amount >= 0, "Amount is too low");
        shareDistributionContract.writeSharesData(
            _address,
            _nounce,
            amount,
            lockTimestamp,
            unlockTimestamp
        );
    }

    function getContracts() external view returns(address _depositToken, address _rewardToken, address _shareDistributionContract) {
        return (address(depositToken), address(rewardToken), address(shareDistributionContract));
    }

    function getTotalDepositedIssuedToken() external view returns(uint depositedTokens, uint issuedTokens) {
        return (totalDepositedToken, totalIssuedToken);
    }

    function getAddressNounce(address _address) external view returns(uint _nounce) {
        return nounce[_address];
    }
}
