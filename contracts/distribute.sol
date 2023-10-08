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
    mapping(uint => Shares) private epochTotalAllocation;

    // track address shares and claimable tokens for an epoch
    mapping(address => mapping(uint => Shares)) private shares;
    mapping(uint => mapping(address => bool)) private isActive;
    mapping(uint => address[]) private epochActiveAddress;

    // track address allocation yet to be claimed accross all epoch
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
        uint epochEndBalance = feeGeneratingToken.balanceOf(address(this));

        // execute distribution here
        epochTotalAllocation[epochHeight].epochClaimableToken = epochEndBalance - totalUnclaimed; // get total amount to distribute from this epoch
        totalUnclaimed += epochTotalAllocation[epochHeight].epochClaimableToken; // update total amount claimable for every previous epoch

        // => Need arrayified info for each writing where each address => their shares
        // => Then new function updateAddressDividends() private => for address in address[] --> totalAllocation[address] += epochTotalAllocation[epochHeight] / shares[address][epochHeight].epochShares
        updateAddressDividends();

        lastDistributionTimestamp = nextDistributionTimestamp;
        nextDistributionTimestamp = lastDistributionTimestamp + 15 days;
        epochHeight++;
    }

    function updateAddressDividends() private { // trouver bon ratio pour la partage du pool
        for (uint i = 0; i <= epochActiveAddress[epochHeight].length; i++) {
            totalAllocation[epochActiveAddress[epochHeight][i]] += epochTotalAllocation[epochHeight].epochClaimableToken * ((shares[epochActiveAddress[epochHeight][i]][epochHeight].epochShares / epochTotalAllocation[epochHeight].epochShares)*100);
        }
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
        uint sharesForLock = (amount * ((unlockTimestamp >= nextDistributionTimestamp ? nextDistributionTimestamp : unlockTimestamp) - (lockTimestamp <= lastDistributionTimestamp ? lastDistributionTimestamp : lockTimestamp))) / 10**5;
        shares[_address][epochHeight].epochShares += sharesForLock;
        epochTotalAllocation[epochHeight].epochShares += sharesForLock;

        if (!isActive[epochHeight][_address]) {
            isActive[epochHeight][_address] = true;
            epochActiveAddress[epochHeight].push(_address);
        }
    }

    function claimDividends(uint amount) external {
        require(amount <= totalUnclaimed, "Not enough tokens to claim");
        require(amount <= totalAllocation[msg.sender], "Amount exceeds address allocation");

        totalAllocation[msg.sender] -= amount;
        totalUnclaimed -= amount;

        feeGeneratingToken.transferFrom(address(this), msg.sender, amount);
    }
}