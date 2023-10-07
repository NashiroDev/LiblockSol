// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";
import "./rLIB.sol";

contract Distributor {
    Liblock private immutable feeGeneratingToken;
    rLiblock private immutable shareToken;

    address private admin;

    uint private nextDistributionTimestamp;
    uint private lastDistributionTimestamp;

    mapping(address => mapping(uint => Allocation)) private currentAllocation;
    mapping(address => uint) private epochShares;

    struct Allocation {
        uint amount;
        uint lockTimestamp;
        uint unlockTimestamp;
    } 
    // ? balance * (lockedTimeInEpoch = nextDistributionTimestamp - lockedTimestamp) 
    // sum(ABOVE) for each lock for address
    //distrib is %(address) of the sum of all the lock during the period

    constructor(address _feeGeneratingToken, address _shareToken) {
        feeGeneratingToken = Liblock(_feeGeneratingToken);
        shareToken = rLiblock(_shareToken);
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

    function clock() external {
        require(nextDistributionTimestamp <= block.timestamp);

        // execute 

        nextDistributionTimestamp = block.timestamp + 15 days;
    }

    function writeSharesData(address _address, uint amount, uint lockTimestamp, uint unlockTimestamp) external onlyAdmin {
        //todo
    }
}