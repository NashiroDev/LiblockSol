// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DDistributor {

    address private admin;

    uint private nextDistributionTimestamp;
    uint private lastDistributionTimestamp;
    uint private epochHeight;
    uint private totalUnclaimed;

    uint public littleShares = 6683650000000000000000;
    uint public bigShares = 7115220000000000000000;
    uint public tokensToDist = 666250000100000000000;

    uint public mapper;

    mapping(uint => address) public debugger1;
    mapping(uint => uint) public debugger2;
    mapping(uint => uint) public debugger3;
    mapping(uint => uint) public debugger4;

    constructor() {
        mapper = 0;
    }

    function test3() public view returns(uint) {
        return tokensToDist*10**18 / bigShares;
    }

    function test4() public view returns(uint) {
        return (test3() * littleShares) / 10**18;
    }

    function test5() public view returns(uint) {
        return (test3() * bigShares) / 10**18;
    }

    function test6() public view returns(uint) {
        return (test3() * (bigShares-littleShares)) / 10**18;
    }
}