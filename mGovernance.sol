// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./proposal.sol";
import "./liblock.sol";

contract Governance {
    constructor(address _token) {
        require(_token != address(0), "Invalid LIB Token address");
        libToken = IERC20(_token);
    }

    Proposal.ArticleProposal[] public proposals;

    uint256 public threshold;

    using SignatureChecker for bytes32;

    // Import and enable usage of ECDSA library
    using ECDSA for bytes32;

    struct Vote {
        uint256 weight;
        bool voted;
        address delegatee;
    }

    mapping(address => Vote) public votes;

    IERC20 public libToken; // Add an instance of your LIB token contract

    modifier onlyTokenHolder() {
        require(
            libToken.balanceOf(msg.sender) > 0,
            "You must hold LIB tokens to vote"
        );
        _;
    }

    function delegate(address delegatee) external onlyTokenHolder {
        address delegator = msg.sender;
        uint256 currentVotingPower = votes[delegator].weight;

        require(delegatee != address(0), "Invalid delegatee address");

        // If already delegated, subtract previous vote weight from delegatee's voting power
        if (
            votes[delegator].voted && votes[delegator].delegatee != address(0)
        ) {
            votes[votes[delegator].delegatee].weight -= currentVotingPower;

            // Reset delegator's previous delegation
            delete votes[delegator];
        }

        // Add current vote weight to new delegatee's voting power
        votes[delegatee].weight += currentVotingPower;

        // Set new delegation for delegator
        votes[delegator] = Vote(currentVotingPower, true, delegatee);
    }

    function vote(
        uint256 proposalId,
        bool support,
        uint256 votingPower,
        bytes memory signature
    ) external onlyTokenHolder {
        require(votingPower > 0, "Invalid voting power");

        bytes32 messageHash = keccak256(
            abi.encodePacked(msg.sender, proposalId, support)
        );

        require(
            messageHash.toEthSignedMessageHash().recover(signature) ==
                msg.sender,
            "Invalid signature"
        );

        // Record the vote from the sender and update voting power...

        votes[msg.sender].weight = votingPower;

        if (
            proposals[proposalId].totalVotes >= threshold &&
            !proposals[proposalId].adopted
        ) executeAction(proposalId);
    }

    function executeAction(uint256 proposalId) internal {
        // Execute proposed action based on governance decision...

        proposals[proposalId].adopted = true;
    }
}
