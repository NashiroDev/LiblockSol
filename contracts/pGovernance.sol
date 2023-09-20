// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./liblock.sol";

contract Governance {
    constructor(address _libToken) {
        require(_libToken != address(0), "Invalid LIB Token address");
        libToken = Liblock(_libToken);
        threshold = 5;
    }

    Liblock public libToken;
    uint256 internal threshold;

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

    modifier hasEnoughDelegatedTokens() {
        require(
            libToken.getVotes(msg.sender) > 100,
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

        uint256 votePower = libToken.getVotes(msg.sender);

        require(!proposal.executed, "Proposal already executed");

        voted[msg.sender][_proposalId] = true;
        proposal.uniqueVotes++;

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
}
