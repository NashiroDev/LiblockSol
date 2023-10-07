// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";

contract Distributor {
    Liblock private immutable feeGeneratingToken;

    address private admin;

    uint private nextDistributionTimestamp;
    uint private lastDistributionTimestamp;
    uint private epochHeight;
    uint private totalUnclaimed;

    // track address locks
    mapping(address => mapping(uint => Allocation)) private currentAllocation;

    // track epoch total token to claim and yet to be claimed
    mapping(uint => Epoch) private epochTotalAllocation;

    // track address shares and claimable tokens for an epoch
    mapping(address => mapping(uint => Shares)) private shares;

    // track address allocation yet to be claimed accross all epoch
    mapping(address => uint) private totalAllocation;

    struct Allocation {
        uint amount;
        uint lockTimestamp;
        uint unlockTimestamp;
    } 

    struct Epoch {
        uint totalEpochTokenClaimable;
        uint totalUnclaimedToken;
    }

    struct Shares {
        uint epochShares;
        uint epochClaimableToken;
    }
    // ? balance * (lockedTimeInEpoch = nextDistributionTimestamp - lockedTimestamp) 
    // sum(ABOVE) for each lock for address
    //distrib is %(address) of the sum of all the lock during the period

    constructor(address _feeGeneratingToken) {
        feeGeneratingToken = Liblock(_feeGeneratingToken);
        admin = msg.sender;
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

    // contract exclusive functions

    function updateEpoch() private {
        require(nextDistributionTimestamp <= block.timestamp, "Not time for new epoch");

        // execute distribution here
        
        lastDistributionTimestamp = nextDistributionTimestamp;
        nextDistributionTimestamp = lastDistributionTimestamp + 15 days;
        epochHeight++;
    }

    function writeSharesData(address _address, uint nounce, uint amount, uint lockTimestamp, uint unlockTimestamp) external onlyAdmin {
        if (nextDistributionTimestamp <= block.timestamp) {
            updateEpoch();
        }
        currentAllocation[_address][nounce] = Allocation (
            amount,
            lockTimestamp,
            unlockTimestamp
        );
        uint SharesForLock = (amount * ((unlockTimestamp >= nextDistributionTimestamp ? nextDistributionTimestamp : unlockTimestamp) - (lockTimestamp <= lastDistributionTimestamp ? lastDistributionTimestamp : lockTimestamp))) / 10**5;
        shares[_address][epochHeight].epochShares += SharesForLock;
    }

    function claimDividends(uint amount) external {
        require(amount <= totalUnclaimed, "Not enough tokens to claim");
        require(amount <= totalAllocation[msg.sender], "Amount exceeds address allocation");

        totalAllocation[msg.sender] -= amount;
        totalUnclaimed -= amount;

        feeGeneratingToken.transferFrom(address(this), msg.sender, amount);
    }
}