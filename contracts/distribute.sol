// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";
import "./rLIB.sol";

contract distributor {
    Liblock private immutable feeGeneratingToken;
    rLiblock private immutable shareToken;

    uint private nextDistributionTimestamp;

    mapping(address => Allocation) private epochAllocation;

    struct Allocation {
        uint[] epochBalances;
        uint[] lockedTimeInEpoch;
    } 
    // ? balance * (lockedTimeInEpoch = nextDistributionTimestamp - lockedTimestamp) 
    // sum(ABOVE) for each lock for address
    //distrib is %(address) of the sum of all the lock during the period

    constructor(address _feeGeneratingToken, address _shareToken) {
        feeGeneratingToken = Liblock(_feeGeneratingToken);
        shareToken = rLiblock(_shareToken);
    }

    function clock() external {
        require(nextDistributionTimestamp <= block.timestamp);

        // execute 

        nextDistributionTimestamp = block.timestamp + 15 days;
    }
}