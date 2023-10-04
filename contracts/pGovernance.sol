// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./liblock.sol";

contract Governance {

    AggregatorV3Interface private dataFeed;

    constructor(address _libToken) {
        require(_libToken != address(0), "Invalid LIB Token address");
        libToken = Liblock(_libToken);
        threshold = 5;
        maxPower = libToken.totalSupply() / 1000;
        setAdmin(msg.sender);
        balancingCount = 0;
        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            0,
            block.timestamp,
            block.timestamp + 1 days,
            10*10**18,
            10*10**8
        );
        dataFeed = AggregatorV3Interface(
            0x59F1ec1f10bD7eD9B938431086bC1D9e233ECf41
        );
    }

    Liblock public libToken;
    uint256 private threshold;
    uint256 public maxPower;
    address internal admin;

    struct Balancing {
        uint id;
        uint blockHeight;
        int currentPrice;
        uint currentTimestamp;
        uint nextTimestamp;
        uint epochFloor;
        uint epochPriceTarget;
    }

    mapping(uint256 => Balancing) public balancing;
    uint256 public balancingCount;

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address creator;
        bool executed;
        bool accepted;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        uint256 uniqueVotes;
        uint256 votingEndTime;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    mapping(address => mapping(uint256 => bool)) public voted;

    modifier onlyAdmin(){
        require(isAdmin(msg.sender));
        _;
    }

    modifier hasEnoughDelegatedTokens() {
        require(
            libToken.getVotes(msg.sender) > balancing[balancingCount].epochFloor,
            "Insufficient delegated tokens"
        );
        _;
    }

    modifier onlyTokenHolderDelegatee() {
        require(
            libToken.balanceOf(msg.sender) > 0,
            "You must hold $LIB tokens to vote"
        );
        require(
            libToken.getVotes(msg.sender) > 0,
            "Insufficient delegated tokens"
        );
        _;
    }

    function setAdmin(address account) private
    {
        require(account != address(0), "Invalid address");
        admin = account;
    }

    function isAdmin(address account) private view returns(bool)
    {
        return admin == account;
    }

    function balanceFloor() external onlyAdmin {
        // require(balancing[balancingCount].nextTimestamp >= block.timestamp);
        balancingCount++;

        (
            /* uint80 roundID */,
            int256 answer,
            /* uint startedAt */,
            uint256 timeStamp,
            /* uint80 answeredInRound */
        ) = dataFeed.latestRoundData();

        uint256 nextPriceTaget = balancing[balancingCount-1].epochPriceTarget + balancing[balancingCount-1].epochPriceTarget / 2000;

        uint256 epochFloor = (nextPriceTaget*10**18 / uint(answer));

        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            answer,
            timeStamp,
            timeStamp + 7 days,
            epochFloor,
            nextPriceTaget
        );
    }

    function createProposal(
        string calldata _title,
        string calldata _description
    ) external hasEnoughDelegatedTokens {
        require(
            bytes(_title).length > 0 && bytes(_description).length > 0,
            "Invalid proposal details"
        );
        proposalCount++;
        proposals[proposalCount] = Proposal(
            proposalCount,
            _title,
            _description,
            msg.sender,
            false,
            false,
            0,
            0,
            0,
            0,
            block.timestamp + 7 days
        );
    }

    function getProposal(
        uint256 _proposalId
    )
        public
        view
        returns (
            uint256 id,
            string memory title,
            string memory description,
            address creator,
            bool executed,
            bool accepted,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 abstainVotes,
            uint256 uniqueVotes,
            uint256 votingEndTime
        )
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.creator,
            proposal.executed,
            proposal.accepted,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.abstainVotes,
            proposal.uniqueVotes,
            proposal.votingEndTime
        );
    }

    function vote(
        uint256 _proposalId,
        string memory _vote
    ) external onlyTokenHolderDelegatee {
        require(
            !voted[msg.sender][_proposalId],
            "Already voted for this proposal"
        );

        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp >= proposal.votingEndTime) {
            checkProposalOutcome(_proposalId);
        }

        require(!proposal.executed, "Proposal already executed");

        uint256 votePower = libToken.getVotes(msg.sender);

        voted[msg.sender][_proposalId] = true;
        proposal.uniqueVotes++;
        
        if (votePower > maxPower)
        {
            if (
            keccak256(abi.encodePacked(_vote)) ==
            keccak256(abi.encodePacked("yes"))
            ) {
                proposal.yesVotes += maxPower;
                proposal.abstainVotes += votePower-maxPower;
            } else if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("no"))
            ) {
                proposal.noVotes += maxPower;
                proposal.abstainVotes += votePower-maxPower;
            } else if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("abstain"))
            ) {
                proposal.abstainVotes += votePower;
            }
        } else {
            if (
            keccak256(abi.encodePacked(_vote)) ==
            keccak256(abi.encodePacked("yes"))
            ) {
                proposal.yesVotes += votePower;
            } else if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("no"))
            ) {
                proposal.noVotes += votePower;
            } else if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("abstain"))
            ) {
                proposal.abstainVotes += votePower;
            }
        }

        
    }

    function calculateProgression(
        uint256 _proposalId
    ) public view returns (uint256, uint256) {
        Proposal storage proposal = proposals[_proposalId];
        uint256 totalVotes = proposal.yesVotes +
            proposal.noVotes +
            proposal.abstainVotes;

        if (totalVotes == 0) {
            return (0, 0);
        }

        uint256 progression = (proposal.yesVotes * 100) / totalVotes;
        return (progression, totalVotes);
    }

    function checkProposalOutcome(uint256 _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];
        uint256 totalVotes = proposal.yesVotes +
            proposal.noVotes +
            proposal.abstainVotes;

        if (totalVotes >= (threshold * libToken.totalSupply()) / 100) {
            if (proposal.yesVotes > (totalVotes - proposal.abstainVotes) / 2) {
                proposal.executed = true;
                proposal.accepted = true;
            } else {
                proposal.executed = true;
                proposal.accepted = false;
            }
        } else {
            proposal.executed = true;
            proposal.accepted = false;
        }
    }

    
    function nextAlterationBlock() external view returns(uint256)
    {
        return balancing[balancingCount].blockHeight + ((balancing[balancingCount].nextTimestamp - balancing[balancingCount].currentTimestamp) / 3); //Sepo scroll
    }
}