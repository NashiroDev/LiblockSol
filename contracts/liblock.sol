// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Liblock is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    ERC20Votes
{
    AggregatorV3Interface internal dataFeed;

    constructor() ERC20("Liblock", "LIB") ERC20Permit("Liblock") {
        _mint(address(this), 75000000 * 10**decimals());
        setAdmin(msg.sender);
        balancingCount = 0;
        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            0,
            block.timestamp,
            block.timestamp + 30.4 days,
            0
        );
        dataFeed = AggregatorV3Interface(
            0x59F1ec1f10bD7eD9B938431086bC1D9e233ECf41
        );
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    address public admin;
    uint256 public balancingCount;

    struct Balancing {
        uint256 id;
        uint256 blockHeight;
        int currentPrice;
        uint256 currentTimestamp;
        uint256 nextTimestamp;
        uint16 lastMonthChange;
    }

    mapping(uint256 => Balancing) public balancing;

    modifier onlyAdmin(){
        require(isAdmin(msg.sender));
        _;
    }

    function setAdmin(address account) private
    {
        require(account != address(0), "Invalid address");
        admin = account;
    }

    function isAdmin(address account) internal view returns(bool)
    {
        return admin == account;
    }

    function mint(uint256 amount)
        external onlyAdmin
    {
        _mint(msg.sender, amount);
    }

    // To Finish
    function alterPrice() public {
        // require(block.timestamp >= balancing[balancingCount].nextTimestamp, "Not time yet");
        balancingCount++;
        (
            /* uint80 roundID */,
            int answer,
            /* uint startedAt */,
            uint timeStamp,
            /* uint80 answeredInRound */
        ) = dataFeed.latestRoundData();


        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            answer,
            timeStamp,
            timeStamp + 30.4 days,
            5
        );
    }

    function nextAlterationBlock() external view returns(uint256)
    {
        return balancing[balancingCount].blockHeight + ((balancing[balancingCount].nextTimestamp - balancing[balancingCount].currentTimestamp) / 3);
    }
}