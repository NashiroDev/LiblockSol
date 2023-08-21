// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Proposal {
    enum Vote { NO, YES, ABSTAIN }

    struct ArticleProposal {
        uint256 id; // Unique ID for each article
        string title;
        string content;
        address proposer;
        bool adopted;
        uint256 totalVotes;
        uint256 votingEndTime; // Stores the end timestamp of the voting period
        mapping(address => Vote) votes; // Mapping to keep track of user votes
    }

    ArticleProposal[] public proposals;

    uint256 private articleIDCounter;

    event ProposalUpdated(uint256 indexed proposalId, uint256 newVoteCount);

    event ProposalCreated(uint256 indexed proposalId);

   /**
     * @dev Create a new proposal with given title and content.
     * @param _title The title of the proposal.
     * @param _content The content or details of the proposal.
     */
    function createProposal(string calldata _title, string calldata _content) external {
        require(bytes(_title).length > 0 && bytes(_content).length > 0, "Invalid proposal details");

        ArticleProposal storage newProposal = proposals.push();
        newProposal.id = getNextArticleID();
        newProposal.title = _title;
        newProposal.content = _content;
        newProposal.proposer = msg.sender;
        newProposal.adopted = false;
        newProposal.totalVotes = 0;

        // Set the voting end time
        newProposal.votingEndTime = block.timestamp + 7 days; // Set a predefined duration for voting (e.g., 7 days)

        emit ProposalCreated(newProposal.id);
    }
    
   /**
     * @dev Update a specific proposal by incrementing its vote count.
     * @param proposalId The ID of the proposal to be updated.
     */
    function updateProposal(uint256 proposalId, Vote userVote) external {
        require(proposalId < proposals.length, "Invalid proposal ID");
        require(!proposals[proposalId].adopted, "Cannot update an adopted proposal");
        require(block.timestamp <= proposals[proposalId].votingEndTime, "Voting period ended");
        
        if (proposals[proposalId].votes[msg.sender] != Vote.NO) {
            revert("Already voted on this proposal");
        }
        
        proposals[proposalId].votes[msg.sender] = userVote;
        
        if (userVote == Vote.YES) {
            proposals[proposalId].totalVotes++;
        }
	
	    emit ProposalUpdated(proposalId, proposals[proposalId].totalVotes);
    }

   /**
     * @dev Get the next available article ID and increment the counter.
     */
    function getNextArticleID() private returns (uint256) {
        uint256 nextArticleID = articleIDCounter;
        articleIDCounter++;
        return nextArticleID;
    }
}