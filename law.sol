// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract liblockDao is Governor, GovernorSettings, GovernorCompatibilityBravo, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl, Ownable {
    constructor(IVotes _token, TimelockController _timelock)
        Governor("liblock")
        GovernorSettings(21600 /* 3 day */, 50400 /* 1 week */, 10e18)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(6)
        GovernorTimelockControl(_timelock)
    {}

    function getDelegates(address _contract, address _account) external view returns (address delegatees) {
    // Use staticcall instead of call to prevent state changes in the called contract
        (bool success, bytes memory result) = _contract.staticcall(abi.encodeWithSignature("delegates(address)", _account));
        
        if (success && result.length >= 32) {
            // Extract the delegate address from the returned bytes data
            assembly {
                delegatees := mload(add(result, 32))
            }
        } else {
            revert("Failed to retrieve delegates");
        }
    }

    function getRemVotes(address _contract, address _account) public view returns (uint256 votes) {
    // Use staticcall instead of call to prevent state changes in the called contract
        (bool success, bytes memory result) = _contract.staticcall(abi.encodeWithSignature("getVotes(address)", _account));

        if (success && result.length >= 32) {
            // Extract the votes from the returned bytes data
            assembly {
                votes := mload(add(result, 32))
            }
        } else {
            revert("Failed to retrieve votes");
        }
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, IGovernor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(Governor, GovernorCompatibilityBravo, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, IERC165, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        public
        override(Governor, IGovernor, GovernorCompatibilityBravo)
        returns (uint256)
    {
        return super.cancel(targets, values, calldatas, descriptionHash);
    }
}