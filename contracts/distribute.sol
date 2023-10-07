// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LIB.sol";
import "./rLIB.sol";

contract distributor {
    Liblock private immutable feeGeneratingToken;
    rLiblock private immutable shareToken;

    uint private nextDistributionTimestamp;

    mapping(address => )

    constructor(address _feeGeneratingToken, address _shareToken) {
        feeGeneratingToken = Liblock(_feeGeneratingToken);
        shareToken = rLiblock(_shareToken);
    }

    function clock() {
        require(nextDistributionTimestamp <= block.timestamp());

        // execute 
        
        nextDistributionTimestamp = block.timestamp() + 15 days;
    }
}