// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";

/**
 * @title Distributor
 * @dev A contract for distributing tokens to multiple addresses based on their shares during an epoch
 */
contract Distributor {
    event DividendsClaimed(address indexed account, uint amount);
    event SharesDataWritten(
        address indexed account,
        uint shares,
        uint lockTimestamp,
        uint unlockTimestamp
    );
    event EpochUpdated(uint epochHeight, uint newTotalUnclaimed);

    Liblock private immutable feeGeneratingToken;

    address private admin;

    uint private nextDistributionTimestamp;
    uint private lastDistributionTimestamp;
    uint private epochHeight;
    uint private totalUnclaimed;

    // track inheritance progress
    mapping(uint => uint[]) private dividendsProgress;
    mapping(address => mapping(uint => uint[])) private inheritanceProgress;

    // track address locks
    mapping(address => mapping(uint => mapping(uint => Allocation))) private epochAllocation;
    mapping(address => mapping(uint => uint)) private nounce;

    // track epoch total shares and token to claimable at the end of the epoch
    mapping(uint => Shares) private epochTotalAllowance;

    // track address shares and claimable tokens for an epoch
    mapping(address => mapping(uint => Shares)) private shares;
    mapping(uint => mapping(address => bool)) private isActive;
    mapping(uint => address[]) private epochActiveAddress;

    // track address total current claimable tokens
    mapping(address => uint) private totalAllocation;

    struct Allocation {
        uint amount;
        uint lockTimestamp;
        uint unlockTimestamp;
    }

    struct Shares {
        uint epochShares;
        uint epochClaimableToken;
    }

    constructor(address _feeGeneratingToken) {
        feeGeneratingToken = Liblock(_feeGeneratingToken);
        admin = msg.sender;
        nextDistributionTimestamp = block.timestamp + 600;
    }

    // admin related stuff

    /**
     * @dev Modifier to check if the caller is the admin.
     */
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not admin");
        _;
    }

    /**
     * @dev Sets a new admin address.
     * @param account The new admin address.
     */
    function setAdmin(address account) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(account != address(this), "Invalid address");
        admin = account;
    }

    /**
     * @dev Checks if the given address is the admin.
     * @param account The address to check.
     * @return A boolean indicating if the address is the admin.
     */
    function isAdmin(address account) private view returns (bool) {
        return admin == account;
    }

    // contract exclusive functions

    /**
     * @dev Increment epoch and initialize dividends calcul
     */
    function updateEpoch() external {
        require(
            nextDistributionTimestamp <= block.timestamp,
            "Not time for new epoch"
        );
        if (epochHeight != 0) {
            require(
            dividendsProgress[epochHeight - 1][0] >=
                dividendsProgress[epochHeight - 1][1],
            "All dividends from previous epoch are not yet proccessed"
        );
        }
        uint epochEndBalance = feeGeneratingToken.balanceOf(address(this));

        epochTotalAllowance[epochHeight].epochClaimableToken =
            epochEndBalance -
            totalUnclaimed;
        totalUnclaimed += epochTotalAllowance[epochHeight].epochClaimableToken;

        lastDistributionTimestamp = nextDistributionTimestamp;
        nextDistributionTimestamp = lastDistributionTimestamp + 30 days;
        epochHeight++;

        if (epochHeight != 0) {
            generateDividendsData();
        }
        
        emit EpochUpdated(epochHeight, totalUnclaimed);
    }

    function generateDividendsData() private {
        dividendsProgress[epochHeight - 1] = [
            0,
            epochActiveAddress[epochHeight - 1].length
        ];
    }

    function generateInheritanceProgress(address _address) private {
        inheritanceProgress[_address][epochHeight - 1] = [
            0,
            nounce[_address][epochHeight - 1] - 1
        ];
    }

    /**
     * @dev Updates the address dividends by calculating the claimable tokens for each address in the range for the last epoch.
     */
    function updateAddressDividends() external {
        require(epochHeight > 0, "There's no reward for epoch -1");
        uint workingEpoch = epochHeight - 1;
        require(
            dividendsProgress[workingEpoch][0] >=
                dividendsProgress[workingEpoch][1],
            "All dividends are already proccessed"
        );

        uint tokenPerShare = (epochTotalAllowance[workingEpoch]
            .epochClaimableToken * 10 ** 18) /
            epochTotalAllowance[workingEpoch].epochShares;
        uint8 looper = dividendsProgress[workingEpoch][1] -
            dividendsProgress[workingEpoch][0] >=
            100
            ? 100
            : uint8(
                dividendsProgress[workingEpoch][1] -
                    dividendsProgress[workingEpoch][0]
            );

        for (
            uint i = dividendsProgress[workingEpoch][0];
            i <= dividendsProgress[workingEpoch][0] + looper;
            i++
        ) {
            address _address = epochActiveAddress[workingEpoch][i];
            shares[_address][workingEpoch].epochClaimableToken =
                (tokenPerShare * shares[_address][workingEpoch].epochShares) /
                10 ** 18;
            totalAllocation[_address] += shares[_address][workingEpoch]
                .epochClaimableToken;
            generateInheritanceProgress(_address);
        }
        dividendsProgress[workingEpoch][0] += looper;
    }

    /**
     * @dev Calculates the current epoch's inheritance for a given address from the last epoch.
     * @param _address The address to calculate the next epoch's inheritance for.
     */
    function currentEpochInheritance(address _address) external {
        require(epochHeight > 0, "There's nothing to inherit from epoch -1");
        uint workingEpoch = epochHeight - 1;
        require(
            inheritanceProgress[_address][workingEpoch].length == 2,
            "Address dividends need to be updated first"
        );
        require(
            nounce[_address][workingEpoch] > 0,
            "Address had no allocation in last epoch"
        );
        require(
            inheritanceProgress[_address][workingEpoch][0] >=
                inheritanceProgress[_address][workingEpoch][1],
            "All inheritances are already proccessed"
        );

        uint8 looper = inheritanceProgress[_address][workingEpoch][0] -
            inheritanceProgress[_address][workingEpoch][0] >=
            10
            ? 10
            : uint8(
                inheritanceProgress[_address][workingEpoch][0] -
                    inheritanceProgress[_address][workingEpoch][0]
            );

        for (
            uint x = inheritanceProgress[_address][workingEpoch][0];
            x <= inheritanceProgress[_address][workingEpoch][0] + looper;
            x++
        ) {
            if (
                epochAllocation[_address][workingEpoch][x].unlockTimestamp >
                nextDistributionTimestamp
            ) {
                uint _amount = epochAllocation[_address][workingEpoch][x]
                    .amount;
                uint _unlockTimestamp = epochAllocation[_address][workingEpoch][
                    x
                ].unlockTimestamp;
                uint _lockTimestamp = epochAllocation[_address][workingEpoch][x]
                    .lockTimestamp;

                epochAllocation[_address][epochHeight][
                    nounce[_address][epochHeight]
                ] = Allocation(_amount, _lockTimestamp, _unlockTimestamp);

                uint sharesForLock = (_amount *
                    ((
                        _unlockTimestamp >= nextDistributionTimestamp
                            ? nextDistributionTimestamp
                            : _unlockTimestamp
                    ) -
                        (
                            _lockTimestamp <= lastDistributionTimestamp
                                ? lastDistributionTimestamp
                                : _lockTimestamp
                        ))) / 10 ** 5;
                shares[_address][epochHeight].epochShares += sharesForLock;
                epochTotalAllowance[epochHeight].epochShares += sharesForLock;

                nounce[_address][epochHeight]++;

                if (!isActive[epochHeight][_address]) {
                    isActive[epochHeight][_address] = true;
                    epochActiveAddress[epochHeight].push(_address);
                }
            }
        }
        inheritanceProgress[_address][workingEpoch][0] += looper;
    }

    /**
     * @dev Writes the shares data for an address in the current epoch.
     * @param _address The address to write the shares data for.
     * @param amount The amount of tokens locked.
     * @param _lockTimestamp The timestamp when the tokens were locked.
     * @param _unlockTimestamp The timestamp when the tokens will be unlocked.
     */
    function writeSharesData(
        address _address,
        uint amount,
        uint _lockTimestamp,
        uint _unlockTimestamp
    ) external onlyAdmin {
        require(
            nextDistributionTimestamp >= block.timestamp,
            "Need to update current epoch"
        );

        epochAllocation[_address][epochHeight][
            nounce[_address][epochHeight]
        ] = Allocation(amount, _lockTimestamp, _unlockTimestamp);
        uint sharesForLock = (amount *
            ((
                _unlockTimestamp >= nextDistributionTimestamp
                    ? nextDistributionTimestamp
                    : _unlockTimestamp
            ) -
                (
                    _lockTimestamp <= lastDistributionTimestamp
                        ? lastDistributionTimestamp
                        : _lockTimestamp
                ))) / 10 ** 5;
        shares[_address][epochHeight].epochShares += sharesForLock;
        epochTotalAllowance[epochHeight].epochShares += sharesForLock;
        nounce[_address][epochHeight]++;

        if (!isActive[epochHeight][_address]) {
            isActive[epochHeight][_address] = true;
            epochActiveAddress[epochHeight].push(_address);
        }

        emit SharesDataWritten(
            _address,
            sharesForLock,
            _lockTimestamp,
            _unlockTimestamp
        );
    }

    /**
     * @dev Allows an address to claim their rewarded token.
     * @param amount The amount of tokens to claim.
     */
    function claimDividends(uint amount) external {
        require(amount <= totalUnclaimed, "Not enough tokens to claim");
        require(
            amount <= totalAllocation[msg.sender],
            "Amount exceeds address allocation"
        );

        totalAllocation[msg.sender] -= amount;
        totalUnclaimed -= amount;

        feeGeneratingToken.transfer(msg.sender, amount);

        emit DividendsClaimed(msg.sender, amount);
    }

    /**
     * @dev Gets the current epoch height.
     * @return epoch - The epoch height.
     */
    function getEpochHeight() external view returns (uint epoch) {
        return epochHeight;
    }

    /**
     * @dev Gets the total unclaimed tokens.
     * @return unclaimed - The total unclaimed tokens.
     */
    function getTotalUnclaimed() external view returns (uint unclaimed) {
        return totalUnclaimed;
    }

    /**
     * @dev Gets the address of the fee generating token.
     * @return tokenAddress - The address of the fee generating token.
     */
    function getFeeTokenAddress() external view returns (address tokenAddress) {
        return address(feeGeneratingToken);
    }

    /**
     * @dev Gets the time left until the next epoch.
     * @return _seconds - The time left in seconds.
     */
    function getEpochTimeLeft() external view returns (uint _seconds) {
        require(
            block.timestamp <= nextDistributionTimestamp,
            "epoch need to be updated"
        );
        return nextDistributionTimestamp - block.timestamp;
    }

    /**
     * @dev Gets the allocation details for a given address, epoch, and nounce.
     * @param _address The address to get the allocation details for.
     * @param _epoch The epoch to get the allocation details for.
     * @param _nounce The nounce to get the allocation details for.
     * @return amount - The amount allocated.
     * @return lockTimestamp - lock timestamp of the allocation.
     * @return unlockTimestamp - Unlock timestamp of the allocation.
     */
    function getEpochAllocation(
        address _address,
        uint _epoch,
        uint _nounce
    )
        external
        view
        returns (uint amount, uint lockTimestamp, uint unlockTimestamp)
    {
        require(_epoch <= epochHeight, "Epoch hasn't appened yet");
        return (
            epochAllocation[_address][_epoch][_nounce].amount,
            epochAllocation[_address][_epoch][_nounce].lockTimestamp,
            epochAllocation[_address][_epoch][_nounce].unlockTimestamp
        );
    }

    /**
     * @dev Gets the total shares and claimable tokens for a given epoch.
     * @param _epoch The epoch to get the shares and tokens for.
     * @return epochTotalShares - The total shares for the epoch.
     * @return epochTotalTokens - The total claimable tokens for the epoch.
     */
    function getEpochShares(
        uint _epoch
    ) external view returns (uint epochTotalShares, uint epochTotalTokens) {
        require(_epoch <= epochHeight, "Epoch hasn't appened yet");
        return (
            epochTotalAllowance[_epoch].epochShares,
            epochTotalAllowance[_epoch].epochClaimableToken
        );
    }

    /**
     * @dev Gets the shares and claimable tokens for a given address and epoch.
     * @param _address The address to get the shares and tokens for.
     * @param _epoch The epoch to get the shares and tokens for.
     * @return epochShares - The shares of an address for an epoch.
     * @return epochTokens - The claimable tokens of an address for an epoch.
     */
    function getAddressEpochShares(
        address _address,
        uint _epoch
    ) external view returns (uint epochShares, uint epochTokens) {
        require(_epoch <= epochHeight, "Epoch hasn't appened yet");
        return (
            shares[_address][_epoch].epochShares,
            shares[_address][_epoch].epochClaimableToken
        );
    }

    /**
     * @dev Gets the nounce for a given address and epoch.
     * @param _address The address to get the nounce for.
     * @param _epoch The epoch to get the nounce for.
     * @return epochNounce - The nounce for the address and epoch.
     */
    function getAddressEpochNounce(
        address _address,
        uint _epoch
    ) external view returns (uint epochNounce) {
        require(_epoch <= epochHeight, "Epoch hasn't appened yet");
        return nounce[_address][_epoch] - 1;
    }

    /**
     * @dev Gets the claimable tokens for a given address.
     * @param _address The address to get the claimable tokens for.
     * @return amount - The amount of claimable tokens left for the address.
     */
    function getAddressClaimableTokens(
        address _address
    ) external view returns (uint amount) {
        return totalAllocation[_address];
    }

    /**
     * @dev Gets the advancement of the calcul of claimable tokens per address.
     * @param _epoch The epoch to get the advancement from.
     * @return processed - The amount of address proccessed.
     * @return totalToProcess - The amount of address to proccess.
     */
    function getEpochProccessAdvancement(
        uint _epoch
    ) external view returns (uint processed, uint totalToProcess) {
        require(_epoch < epochHeight, "Epoch hasn't appened yet");
        return (dividendsProgress[_epoch][0], dividendsProgress[_epoch][1]);
    }

    /**
     * @dev Gets the inheritance progression for an address in an epoch
     * @param _address The address to get the inheritance data from.
     * @param _epoch The epoch to get the inheritance data from.
     * @return processed - The amount of allocations proccessed.
     * @return totalToProcess - The amount of allocations to proccess.
     */
    function getAddressEpochInheritance(
        address _address,
        uint _epoch
    ) external view returns (uint processed, uint totalToProcess) {
        require(_epoch < epochHeight, "Epoch hasn't appened yet");
        return (
            inheritanceProgress[_address][_epoch][0],
            inheritanceProgress[_address][_epoch][1]
        );
    }
}
