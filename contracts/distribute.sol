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
    mapping(address => mapping(uint => mapping(uint => Allocation))) private epochAllocation;
    mapping(address => mapping(uint => uint)) private nounce;

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

    function updateEpoch() external {
        require(
            nextDistributionTimestamp <= block.timestamp,
            "Not time for new epoch"
        );
        uint epochEndBalance = feeGeneratingToken.balanceOf(address(this));

        epochTotalAllocation[epochHeight].epochClaimableToken =
            epochEndBalance -
            totalUnclaimed;
        totalUnclaimed += epochTotalAllocation[epochHeight].epochClaimableToken;

        updateAddressDividends();

        lastDistributionTimestamp = nextDistributionTimestamp;
        nextDistributionTimestamp = lastDistributionTimestamp + 15 days;
        epochHeight++;
    }

    function updateAddressDividends() private {
        uint tokenPerShare = epochTotalAllocation[epochHeight].epochClaimableToken*10**18 / epochTotalAllocation[epochHeight].epochShares;
        for (uint i = 0; i < epochActiveAddress[epochHeight].length; i++) {
            address _address = epochActiveAddress[epochHeight][i];
            shares[_address][epochHeight].epochClaimableToken = (tokenPerShare * shares[_address][epochHeight].epochShares) / 10**18;
            totalAllocation[_address] += shares[_address][epochHeight]
                .epochClaimableToken;
            nextEpochInheritance(_address);
        }
    }

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
                epochTotalAllocation[epochHeight+1]
                    .epochShares += sharesForLock;

                nounce[_address][epochHeight+1]++;

                if (!isActive[epochHeight+1][_address]) {
                    isActive[epochHeight+1][_address] = true;
                    epochActiveAddress[epochHeight+1].push(_address);
                }
            }
        }
    }

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
        epochTotalAllocation[epochHeight].epochShares += sharesForLock;
        nounce[_address][epochHeight]++;

        if (!isActive[epochHeight][_address]) {
            isActive[epochHeight][_address] = true;
            epochActiveAddress[epochHeight].push(_address);
        }
    }

    function claimDividends(uint amount) external {
        require(amount <= totalUnclaimed, "Not enough tokens to claim");
        require(
            amount <= totalAllocation[msg.sender],
            "Amount exceeds address allocation"
        );

        feeGeneratingToken.approveFrom(msg.sender, amount);

        totalAllocation[msg.sender] -= amount;
        totalUnclaimed -= amount;

        feeGeneratingToken.transferFrom(address(this), msg.sender, amount);
    }

    function getEpochHeight() external view returns (uint epoch) {
        return epochHeight;
    }

    function getTotalUnclaimed() external view returns (uint unclaimed) {
        return totalUnclaimed;
    }

    function getFeeTokenAddress() external view returns (address tokenAddress) {
        return address(feeGeneratingToken);
    }

    function getEpochTimeLeft() external view returns (uint _seconds) {
        require(
            (nextDistributionTimestamp - block.timestamp) >= 0,
            "epoch need to be updated"
        );
        return nextDistributionTimestamp - block.timestamp;
    }

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

    function getEpochShares(
        uint _epoch
    ) external view returns (uint epochTotalShares, uint epochTotalTokens) {
        return (
            epochTotalAllocation[_epoch].epochShares,
            epochTotalAllocation[_epoch].epochClaimableToken
        );
    }

    function getAddressEpochShares(
        address _address,
        uint _epoch
    ) external view returns (uint epochShares, uint epochTokens) {
        return (
            shares[_address][_epoch].epochShares,
            shares[_address][_epoch].epochClaimableToken
        );
    }

    function getAddressEpochNounce(address _address, uint _epoch) external view returns(uint epochNounce) {
        return nounce[_address][_epoch];
    }

    function getAddressClaimableTokens(
        address _address
    ) external view returns (uint amount) {
        return totalAllocation[_address];
    }
}