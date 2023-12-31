// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./LIB.sol";
import "./rLIB.sol";

contract gProposal {
    event NewProposal(uint indexed proposalId, string title, address indexed creator);
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

    modifier hasEnoughDelegatedTokens() {
        require(
            rlibToken.getVotes(msg.sender) >=
                balancing[balancingCount].epochFloor,
            "Insufficient delegated rLIB tokens"
        );
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
    function isAdmin(address account) private view returns (bool) {
        return admin == account;
    }

    /**
     * @dev Updates the balance floor price neccessary to submit a proposal
     * This function can only be called by the admin
     * This function can only be called each 7days
     */
    function balanceFloor() external {
        require(
            balancing[balancingCount].nextTimestamp < block.timestamp,
            "Not time yet"
        );
        balancingCount++;
        uint bc = balancingCount;

        (
            ,
            /* uint80 roundID */ int answer,
            ,
            /* uint startedAt */ uint timeStamp,

        ) = /* uint80 answeredInRound */
            dataFeed.latestRoundData();

        uint nextPriceTaget = balancing[bc - 1].epochPriceTarget +
            balancing[bc - 1].epochPriceTarget /
            2000;

        uint epochFloor = ((nextPriceTaget * 10 ** 18) / uint(answer));

        balancing[bc] = Balancing(
            bc,
            block.number,
            answer,
            timeStamp,
            timeStamp + 7 days,
            epochFloor,
            nextPriceTaget
        );

        emit BalancingExecuted(bc, epochFloor);
    }

    /**
     * @dev Creates a new proposal
     * @param _title The title of the proposal
     * @param _description The description of the proposal
     */
    function createProposal(
        string calldata _title,
        string calldata _description
    ) external hasEnoughDelegatedTokens {
        require(
            bytes(_title).length > 0 && bytes(_description).length > 0,
            "Invalid proposal details"
        );

        address sender = msg.sender;
        uint pc = proposalCount;

        deduceVirtualPower(sender);

        proposals[pc] = Proposal(
            pc,
            _title,
            _description,
            sender,
            false,
            false,
            0,
            0,
            0,
            0,
            block.timestamp + 7 days
        );
        proposalCount++;

        emit NewProposal(pc - 1, _title, sender);
    }

    /**
     * @dev Retrieves the details of a proposal
     * @param _proposalId The ID of the proposal
     * @return id The ID of the proposal
     * @return title The title of the proposal
     * @return description The description of the proposal
     * @return creator The address of the creator of the proposal
     * @return executed A boolean indicating if the proposal has been executed
     * @return accepted A boolean indicating if the proposal has been accepted
     * @return yesVotes The number of "yes" votes received
     * @return noVotes The number of "no" votes received
     * @return abstainVotes The number of "abstain" votes received
     * @return uniqueVotes The number of unique voters
     * @return votingEndTime The end time of the voting period
     */
    function getProposal(
        uint _proposalId
    )
        public
        view
        returns (
            uint id,
            string memory title,
            string memory description,
            address creator,
            bool executed,
            bool accepted,
            uint yesVotes,
            uint noVotes,
            uint abstainVotes,
            uint uniqueVotes,
            uint votingEndTime
        )
    {
        require(_proposalId < proposalCount, "No proposal exist for this id");
        Proposal memory proposal = proposals[_proposalId];
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

    /**
     * @dev Allows a token holder to vote on a proposal
     * @param _proposalId The ID of the proposal
     * @param _vote The vote ("yes", "no", or "abstain")
     */
    function vote(
        uint _proposalId,
        bytes32 _vote
    ) external onlyDelegatee {
        address sender = msg.sender;
        require(
            !voted[sender][_proposalId],
            "Already voted for this proposal"
        );

        Proposal storage proposal = proposals[_proposalId];

        if (block.timestamp >= proposal.votingEndTime) {
            checkProposalOutcome(_proposalId);
        }

        require(!proposal.executed, "Proposal already executed");

        uint votePower = libToken.getVotes(sender) +
            rlibToken.getVotes(sender);

        voted[sender][_proposalId] = true;
        proposal.uniqueVotes++;

        if (votePower > maxPower) {
            if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("yes"))
            ) {
                proposal.yesVotes += maxPower;
                proposal.abstainVotes += votePower - maxPower;
            } else if (
                keccak256(abi.encodePacked(_vote)) ==
                keccak256(abi.encodePacked("no"))
            ) {
                proposal.noVotes += maxPower;
                proposal.abstainVotes += votePower - maxPower;
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

        emit Vote(_proposalId, sender);
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
        require(block.timestamp >= proposal.votingEndTime, "The proposal is still being voted");
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
     * @dev Returns the block number for the next alteration
     * @return The block number
     */
    function nextAlterationBlock() external view returns (uint) {
        Balancing memory alter = balancing[balancingCount];
        return
            alter.blockHeight +
            ((alter.nextTimestamp - alter.currentTimestamp) / 3); //Sepo scroll
    }

    /**
     * @dev Deduce VP needed for creating a new proposal
     * @param _address The address to deduce the VP
     */
    function deduceVirtualPower(address _address) private {
        Balancing memory alter = balancing[balancingCount];
        require(
            rlibToken.getVotes(_address) -
                virtualPowerUsed[_address][balancingCount] >=
                alter.epochFloor,
            "Not enough rLIB VP left"
        );
        virtualPowerUsed[_address][balancingCount] += alter.epochFloor;
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
