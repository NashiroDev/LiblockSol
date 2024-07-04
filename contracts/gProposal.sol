// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./LIB.sol";
import "./rLIB.sol";

contract gProposal {
    event NewProposal(
        uint indexed proposalId,
        string title,
        address indexed creator
    );
    event ProposalExecuted(uint indexed proposalId, bool indexed accepted);
    event Vote(uint indexed proposalId, address indexed voter);
    event BalancingExecuted(uint indexed balancingId, uint indexed floor);

    Liblock public immutable libToken;
    rLiblock public immutable rlibToken;

    uint public proposalCount;
    uint public balancingCount;
    uint public maxPower;

    uint16 private libThreshold;
    uint16 private rlibThreshold;
    address private admin;

    AggregatorV3Interface private dataFeed;

    // Track balancing of min VP to submit a proposals
    mapping(uint256 => Balancing) public balancing;

    // Track VP used per address and balancing epoch
    mapping(address => mapping(uint => uint)) public virtualPowerUsed;

    // Track created proposals & votes on them
    mapping(uint => Proposal) public proposals;
    mapping(address => mapping(uint => bool)) public voted;

    struct Balancing {
        uint id;
        uint blockHeight;
        int currentPrice;
        uint currentTimestamp;
        uint nextTimestamp;
        uint epochFloor;
        uint epochPriceTarget;
    }

    struct Proposal {
        uint id;
        string title;
        string description;
        address creator;
        bool executed;
        bool accepted;
        uint yesVotes;
        uint noVotes;
        uint abstainVotes;
        uint uniqueVotes;
        uint votingEndTime;
    }

    constructor(address _libToken, address _rlibToken) {
        require(_libToken != address(0), "Invalid LIB Token address");
        libToken = Liblock(_libToken);
        rlibToken = rLiblock(_rlibToken);
        libThreshold = 5;
        rlibThreshold = 40;
        maxPower = libToken.totalSupply() / 1000;
        setAdmin(msg.sender);
        balancingCount = 0;
        proposalCount = 0;
        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            0,
            block.timestamp,
            block.timestamp + 1 days,
            10 * 10 ** 18,
            10 * 10 ** 8
        );
        dataFeed = AggregatorV3Interface(
            0x59F1ec1f10bD7eD9B938431086bC1D9e233ECf41
        );
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    modifier onlyDelegatee() {
        require(
            libToken.getVotes(msg.sender) > 0,
            "Insufficient delegated tokens"
        );
        _;
    }

    /**
     * @dev Sets the contract admin
     * @param account The address of the admin
     */
    function setAdmin(address account) private {
        require(account != address(0), "Invalid address");
        admin = account;
    }

    /**
     * @dev Checks if the given address is the admin
     * @param account The address to check
     * @return A boolean indicating if the address is the admin
     */
    function isAdmin(address account) public view returns (bool) {
        return admin == account;
    }

    /**
     * @dev Updates the balance floor price neccessary to submit a proposal
     * This function can only be called by the admin
     * This function can only be called each 7days
     */
    function balanceFloor() external {
        require(
            block.timestamp >= balancing[balancingCount].nextTimestamp,
            "Not time yet"
        );

        (, int answer, , uint timeStamp, ) = dataFeed.latestRoundData();

        uint nextPriceTarget = (balancing[balancingCount].epochPriceTarget *
            1005) / 1000; // Simplified calculation
        uint epochFloor = (nextPriceTarget * 1e18) / uint(answer);

        balancingCount++;
        balancing[balancingCount] = Balancing(
            balancingCount,
            block.number,
            answer,
            timeStamp,
            timeStamp + 7 days,
            epochFloor,
            nextPriceTarget
        );

        emit BalancingExecuted(balancingCount, epochFloor);
    }

    /**
     * @dev Creates a new proposal
     * @param _title The title of the proposal
     * @param _description The description of the proposal
     */
    function createProposal(string calldata _title, string calldata _description) external {
        require(bytes(_title).length > 0 && bytes(_description).length > 0, "Invalid proposal details");
        
        uint256 requiredVotes = balancing[balancingCount].epochFloor;
        uint256 availableVotes = rlibToken.getVotes(msg.sender) - virtualPowerUsed[msg.sender][balancingCount];
        
        require(availableVotes >= requiredVotes, "Insufficient VP");

        virtualPowerUsed[msg.sender][balancingCount] += requiredVotes;

        proposals[proposalCount++] = Proposal(
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

        emit NewProposal(proposalCount - 1, _title, msg.sender);
    }

    /**
     * @dev Allows a token holder to vote on a proposal
     * @param _proposalId The ID of the proposal
     * @param _vote The vote ("yes", "no", or "abstain")
     */
    function vote(uint _proposalId, bytes32 _vote) external onlyDelegatee {
        require(!voted[msg.sender][_proposalId], "Already voted");

        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");

        if (block.timestamp >= proposal.votingEndTime) {
            checkProposalOutcome(_proposalId);
            require(!proposal.executed, "Proposal already executed");
        }

        uint votePower = libToken.getVotes(msg.sender) + rlibToken.getVotes(msg.sender);
        voted[msg.sender][_proposalId] = true;
        proposal.uniqueVotes++;

        if (votePower > maxPower) {
            votePower = maxPower;
            proposal.abstainVotes += votePower - maxPower;
        }

        if (_vote == "yes") proposal.yesVotes += votePower;
        else if (_vote == "no") proposal.noVotes += votePower;
        else if (_vote == "abstain") proposal.abstainVotes += votePower;

        emit Vote(_proposalId, msg.sender);
    }

    /**
     * @dev Calculates the progression of a proposal
     * @param _proposalId The ID of the proposal
     * @return progression The progression percentage
     * @return totalVotes The total number of votes
     */
    function calculateProgression(
        uint _proposalId
    ) external view returns (uint, uint) {
        require(_proposalId < proposalCount, "No proposal exist for this id");
        Proposal memory proposal = proposals[_proposalId];
        uint totalVotes = proposal.yesVotes +
            proposal.noVotes +
            proposal.abstainVotes;

        if (totalVotes == 0) {
            return (0, 0);
        }

        uint progression = (proposal.yesVotes * 100) / totalVotes;
        return (progression, totalVotes);
    }

    /**
     * @dev Checks the outcome of a proposal
     * @param _proposalId The ID of the proposal
     */
    function checkProposalOutcome(uint _proposalId) private {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp >= proposal.votingEndTime,
            "The proposal is still being voted"
        );
        uint totalVotes = proposal.yesVotes +
            proposal.noVotes +
            proposal.abstainVotes;

        if (
            totalVotes >=
            (libThreshold * libToken.totalSupply()) /
                100 +
                (rlibThreshold * rlibToken.totalSupply()) /
                100
        ) {
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

        emit ProposalExecuted(_proposalId, proposal.accepted);
    }

    /**
     * @dev Checks the outcome of a proposal
     * @param _proposalId The ID of the proposal
     */
    function executeProposal(uint _proposalId) external {
        checkProposalOutcome(_proposalId);
    }

    /**
     * @dev Returns the minimum time left for the next alteration
     * @return The time left in seconds
     */
    function nextAlterationTimeLeft() external view returns (uint) {
        Balancing memory alter = balancing[balancingCount];
        return
            block.timestamp >= alter.nextTimestamp
                ? 0
                : alter.nextTimestamp - block.timestamp;
    }

    /**
     * @dev Allow admin to alter thresholds
     * @param _libThreshold Threshold for the LIB token.
     * @param _rlibThreshold Threshold for the rLIB token.
     */
    function setNewThresholds(
        uint8 _libThreshold,
        uint8 _rlibThreshold
    ) external onlyAdmin {
        require(_libThreshold > 0 && _rlibThreshold > 0, "Invalid");
        libThreshold = _libThreshold;
        rlibThreshold = _rlibThreshold;
    }
}
