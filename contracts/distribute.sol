// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";

/**
* @title Distributor
* @dev A contract for distributing tokens to multiple addresses based on their shares during an epoch
*/
contract Distributor {

    event DividendsClaimed(address indexed account, uint amount);
    event SharesDataWritten(address indexed account, uint shares, uint lockTimestamp, uint unlockTimestamp);
    event EpochUpdated(uint epochHeight, uint newTotalUnclaimed);

    Liblock private immutable feeGeneratingToken;

    address private admin;

    uint private nextDistributionTimestamp;
    uint private lastDistributionTimestamp;
    uint private epochHeight;
    uint private totalUnclaimed;

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
    * @dev Calculate the number of tokens to reward for the epoch then increment epoch
    */
    function updateEpoch() external {
        require(
            nextDistributionTimestamp <= block.timestamp,
            "Not time for new epoch"
        );
        uint epochEndBalance = feeGeneratingToken.balanceOf(address(this));

        epochTotalAllowance[epochHeight].epochClaimableToken =
            epochEndBalance -
            totalUnclaimed;
        totalUnclaimed += epochTotalAllowance[epochHeight].epochClaimableToken;

        updateAddressDividends();

        lastDistributionTimestamp = nextDistributionTimestamp;
        nextDistributionTimestamp = lastDistributionTimestamp + 15 days;
        epochHeight++;

        emit EpochUpdated(epochHeight, totalUnclaimed);
    }

    /**
    * @dev Updates the address dividends by calculating the claimable tokens for each address in the current epoch.
    */
    function updateAddressDividends() private {
        uint tokenPerShare = epochTotalAllowance[epochHeight].epochClaimableToken*10**18 / epochTotalAllowance[epochHeight].epochShares;
        for (uint i = 0; i < epochActiveAddress[epochHeight].length; i++) {
            address _address = epochActiveAddress[epochHeight][i];
            shares[_address][epochHeight].epochClaimableToken = (tokenPerShare * shares[_address][epochHeight].epochShares) / 10**18;
            totalAllocation[_address] += shares[_address][epochHeight]
                .epochClaimableToken;
            nextEpochInheritance(_address);
        }
    }

    /**
    * @dev Calculates the next epoch's inheritance for a given address by checking the remaining locks in the current epoch.
    * @param _address The address to calculate the next epoch's inheritance for.
    */
    function nextEpochInheritance(address _address) private {
        for (uint x = 0; x <= nounce[_address][epochHeight]; x++) {
            if (
                epochAllocation[_address][epochHeight][x].unlockTimestamp >
                nextDistributionTimestamp
            ) {
                uint _amount = epochAllocation[_address][epochHeight][x].amount;
                uint _unlockTimestamp = epochAllocation[_address][epochHeight][x]
                    .unlockTimestamp;
                uint _lockTimestamp = epochAllocation[_address][epochHeight][x]
                    .lockTimestamp;

                epochAllocation[_address][epochHeight+1][nounce[_address][epochHeight+1]] = Allocation(
                    _amount,
                    _lockTimestamp,
                    _unlockTimestamp
                );

                uint sharesForLock = (_amount *
                    ((_unlockTimestamp >= nextDistributionTimestamp ? nextDistributionTimestamp : _unlockTimestamp) -
                        (_lockTimestamp <= lastDistributionTimestamp ? lastDistributionTimestamp : _lockTimestamp))) / 10 ** 5;
                shares[_address][epochHeight+1].epochShares += sharesForLock;
                epochTotalAllowance[epochHeight+1]
                    .epochShares += sharesForLock;

                nounce[_address][epochHeight+1]++;

                if (!isActive[epochHeight+1][_address]) {
                    isActive[epochHeight+1][_address] = true;
                    epochActiveAddress[epochHeight+1].push(_address);
                }
            }
        }
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

        epochAllocation[_address][epochHeight][nounce[_address][epochHeight]] = Allocation(
            amount,
            _lockTimestamp,
            _unlockTimestamp
        );
        uint sharesForLock = (amount *
            ((_unlockTimestamp >= nextDistributionTimestamp ? nextDistributionTimestamp : _unlockTimestamp) -
                (_lockTimestamp <= lastDistributionTimestamp ? lastDistributionTimestamp : _lockTimestamp))) / 10 ** 5;
        shares[_address][epochHeight].epochShares += sharesForLock;
        epochTotalAllowance[epochHeight].epochShares += sharesForLock;
        nounce[_address][epochHeight]++;

        if (!isActive[epochHeight][_address]) {
            isActive[epochHeight][_address] = true;
            epochActiveAddress[epochHeight].push(_address);
        }

        emit SharesDataWritten(_address, sharesForLock, _lockTimestamp, _unlockTimestamp);
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
        require(block.timestamp <= nextDistributionTimestamp, "epoch need to be updated");
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
    function getAddressEpochNounce(address _address, uint _epoch) external view returns(uint epochNounce) {
        return nounce[_address][_epoch]-1;
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
}