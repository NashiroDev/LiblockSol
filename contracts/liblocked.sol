// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LIB.sol";
import "./rLIB.sol";
import "./distributor.sol";
import "./lockTokens.sol";

/**
* @title TokenStaking
* @dev A contract for staking tokens and earning rewards based on different lock durations and amount locked
*/
contract Liblocked {
    Liblock private immutable depositToken; // The token to stake
    rLiblock private immutable rewardToken; // The token rewarded for a stake
    Distributor private immutable shareDistributionContract; // The contract responsible for distributing shares of the fee pool

    uint private totalDepositedToken; // Total amount of tokens stacked at the moment
    uint private totalIssuedToken; // Total amount of tokens rewarded at the moment

    event TokensLocked(address indexed user, uint indexed amount, uint indexed unlockAt);
    event TokensWithdrawn(address indexed user, uint indexed amount);

    mapping(address => mapping(uint => Ledger)) public ledger; // Mapping to store the user's token staking information
    mapping(address => uint) private nounce; // Mapping to store the user's nounce (to keep track of their token staking records)

    struct Ledger {
        uint amountDeposited;
        uint amountIssued;
        uint8 ratio;
        uint lockedAt;
        uint lockUntil;
        TokenTimelock lock;
    }

    /**
    * @dev Constructor function
    * @param _depositToken The address of the deposit token
    * @param _rewardToken The address of the reward token
    * @param _shareDistributionContract The address of the share distribution contract
    */
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

    /**
    * @dev Lock tokens for 17 days - ratio of 1:1
    * @param amount The amount of tokens to lock
    */
    function lockTest(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 100, 1 days, sender);
    }

    /**
    * @dev Lock tokens for 17 days - ratio of 1:1
    * @param amount The amount of tokens to lock
    */
    function lock17(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 100, 17 days, sender);
    }

    /**
    * @dev Lock tokens for 31 days - ratio of 1:1.05
    * @param amount The amount of tokens to lock
    */
    function lock31(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 105, 31 days, sender);
    }

    /**
    * @dev Lock tokens for 93 days - ratio of 1:1.25
    * @param amount The amount of tokens to lock
    */
    function lock93(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 125, 93 days, sender);
    }

    /**
    * @dev Lock tokens for 186 days - ratio of 1:1.45
    * @param amount The amount of tokens to lock
    */
    function lock186(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 145, 186 days, sender);
    }

    /**
    * @dev Lock tokens for 279 days - ratio of 1:1.6
    * @param amount The amount of tokens to lock
    */
    function lock279(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 160, 279 days, sender);
    }

    /**
    * @dev Lock tokens for 365 days - ratio of 1:1.7
    * @param amount The amount of tokens to lock
    */
    function lock365(uint amount) external {
        address sender = msg.sender;
        require(
            amount <= depositToken.balanceOf(sender),
            "Not enough tokens"
        );
        lockTokens(amount, 170, 365 days, sender);
    }

    /**
    * @dev Internal function to lock tokens for a specific duration
    * @param amount The amount of tokens to lock
    * @param ratio The ratio used for calculating reward tokens based on deposited tokens
    * @param lockDuration The duration for which the tokens will be locked
    */
    function lockTokens(
        uint256 amount,
        uint8 ratio,
        uint32 lockDuration,
        address sender
    ) private {
        require(amount > 0, "Amount must be greater than zero");
        require(ratio <= 200, "Ratio is too high");
        require(
            depositToken.allowance(sender, address(this)) >= amount,
            "Not enough LIB allowance"
        );

        uint bt = block.timestamp;

        uint256 rewardAmount = (amount * ratio) / 10 ** 2;

        TokenTimelock lock = new TokenTimelock(
            depositToken,
            sender,
            bt + lockDuration,
            address(this)
        );

        requestNewFeeExcludedAddress(address(lock), true);

        depositToken.transferFrom(sender, address(lock), amount);
        requestMint(rewardAmount);

        requestDelegationDeposit(address(lock), sender);
        requestDelegationReward(sender, sender);

        ledger[sender][nounce[sender]] = Ledger(
            amount,
            rewardAmount,
            ratio,
            bt,
            bt + lockDuration,
            lock
        );

        sendSharesData(
            sender,
            rewardAmount,
            bt,
            bt + lockDuration
        );

        nounce[sender]++;
        totalDepositedToken += amount;
        totalIssuedToken += rewardAmount;

        emit TokensLocked(sender, amount, bt + lockDuration);
    }

    /**
    * @dev Withdraw locked tokens
    * @param _nounce The nounce of the deposit with tokens to be withdrawn
    */
    function withdrawTokens(uint _nounce) external {
        address sender = msg.sender;
        Ledger memory l = ledger[sender][_nounce];
        TokenTimelock lock = l.lock;
        uint amountIssued = l.amountIssued;
        uint amountDeposited = l.amountDeposited;

        require(
            rewardToken.allowance(sender, address(this)) >= amountIssued,
            "Not enough rLIB allowance"
        );
        require(
            rewardToken.balanceOf(sender) >= amountIssued,
            "Not enough rLIB to withdraw"
        );
        require(
            address(lock) != address(0),
            "No tokens locked for this nounce"
        );

        lock.release();
        requestBurn(amountIssued);

        requestNewFeeExcludedAddress(address(lock), false);
        requestDelegationDeposit(sender, sender);

        totalDepositedToken -= amountDeposited;
        totalIssuedToken -= amountIssued;

        emit TokensWithdrawn(sender, amountIssued);
    }

    /**
    * @dev Get the lock time remaining in seconds
    * @param _address The address of the user
    * @param _nounce The nounce of the deposit
    * @return lockTime - The remaining lock time in seconds
    */
    function getLockTimeRemaining(
        address _address,
        uint _nounce
    ) external view returns (uint lockTime) {
        require(
            _nounce < nounce[_address],
            "This nounce do not exist for this address"
        );
        uint bt = block.timestamp;
        Ledger memory l = ledger[_address][_nounce];
        require(bt < l.lockUntil, "Tokens already unlocked");
        return l.lockUntil - bt;
    }

    /**
    * @dev Private function to request adding or removing a fee excluded address to the stacking token contract
    * @param _address The address to be added or removed
    * @param _excluded Boolean indicating whether to add or remove the address
    */
    function requestNewFeeExcludedAddress(
        address _address,
        bool _excluded
    ) private {
        depositToken.setFeeExcludedAddress(_address, _excluded);
    }

    /**
    * @dev Internal function to request delegation of remote tokens to the stacking token contract
    * @param delegator The address of the delegator
    * @param delegatee The address of the delegatee
    */
    function requestDelegationDeposit(
        address delegator,
        address delegatee
    ) private {
        depositToken.delegateFrom(delegator, delegatee);
    }

    /**
    * @dev Private function to request delegation of reward tokens to the reward token contract
    * @param delegator The address of the delegator
    * @param delegatee The address of the delegatee
    */
    function requestDelegationReward(
        address delegator,
        address delegatee
    ) private {
        rewardToken.delegateFrom(delegator, delegatee);
    }

    /**
    * @dev Private function to request minting of reward tokens to the sender address
    * @param amount The amount of reward tokens to mint
    */
    function requestMint(uint amount) private {
        rewardToken.mint(msg.sender, amount);
    }

    /**
    * @dev Internal function to request burning of reward tokens from the sender address
    * @param amount The amount of reward tokens to burn
    */
    function requestBurn(uint amount) private {
        rewardToken.burn(msg.sender, amount);
    }

    /**
    * @dev Private function to send shares data to the token and shares distribution contract
    * @param _address The address of the user
    * @param amount The amount of reward tokens
    * @param lockTimestamp The timestamp when the tokens were locked
    * @param unlockTimestamp The timestamp when the tokens can be unlocked
    */
    function sendSharesData(
        address _address,
        uint amount,
        uint lockTimestamp,
        uint unlockTimestamp
    ) private {
        require(amount >= 0, "Amount is too low");
        shareDistributionContract.writeSharesData(
            _address,
            amount,
            lockTimestamp,
            unlockTimestamp
        );
    }

    /**
    * @dev Get the addresses of the associated contracts
    * @return _depositToken - The address of the deposit token
    * @return _rewardToken - The address of the reward token
    * @return _shareDistributionContract - The address of the share distribution contract
    */
    function getContracts() external view returns(address _depositToken, address _rewardToken, address _shareDistributionContract) {
        return (address(depositToken), address(rewardToken), address(shareDistributionContract));
    }

    /**
    * @dev Get the total deposited and issued tokens
    * @return depositedTokens - The total deposited tokens at the moment
    * @return issuedTokens - The total issued reward tokens at the moment
    */
    function getTotalDepositedIssuedToken() external view returns(uint depositedTokens, uint issuedTokens) {
        return (totalDepositedToken, totalIssuedToken);
    }

    /**
    * @dev Get the nounce of the given address
    * @param _address The address of the user
    * @return _nounce The nounce of the user
    */
    function getAddressNounce(address _address) external view returns(uint _nounce) {
        return nounce[_address]-1;
    }
}
