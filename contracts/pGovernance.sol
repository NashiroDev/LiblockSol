// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Governance {
    constructor(address _token) {
        require(_token != address(0), "Invalid LIB Token address");
        libToken = IERC20(_token);
        threshold = 5;
    }

    using SignatureChecker for bytes32;
    using ECDSA for bytes32;

    IERC20 public libToken;
    uint256 internal threshold;

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address creator;
        bool executed;
        bool accepted;
        uint256 threshold;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 abstainVotes;
        uint256 votingEndTime;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    mapping(address => uint256) public delegatedBalances;
    mapping(address => mapping(uint256 => bool)) public voted;

    modifier hasEnoughDelegatedTokens() {
        require(
            delegatedBalances[msg.sender] > 100,
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
            delegatedBalances[msg.sender] > 0,
            "Insufficient delegated tokens"
        );
        _;
    }

    function createProposal(
        string calldata _title,
        string calldata _description
    ) public hasEnoughDelegatedTokens {
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
            threshold,
            0,
            0,
            0,
            block.timestamp + 7 days
        );
    }

    function vote(
        uint256 _proposalId,
        string memory _vote
    ) public onlyTokenHolderDelegatee {
        require(
            !voted[msg.sender][_proposalId],
            "Already voted for this proposal"
        );

        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp >= proposal.votingEndTime) {
            checkProposalOutcome(_proposalId);
        }

        require(!proposal.executed, "Proposal already executed");

        if (
            keccak256(abi.encodePacked(_vote)) ==
            keccak256(abi.encodePacked("yes"))
        ) {
            proposal.yesVotes++;
        } else if (
            keccak256(abi.encodePacked(_vote)) ==
            keccak256(abi.encodePacked("no"))
        ) {
            proposal.noVotes++;
        } else if (
            keccak256(abi.encodePacked(_vote)) ==
            keccak256(abi.encodePacked("abstain"))
        ) {
            proposal.abstainVotes++;
        }

        voted[msg.sender][_proposalId] = true;
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

        if (block.timestamp >= proposal.votingEndTime) {
            if (totalVotes >= (threshold * libToken.totalSupply()) / 100) {
                if (
                    proposal.yesVotes > (totalVotes - proposal.abstainVotes) / 2
                ) {
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
}
