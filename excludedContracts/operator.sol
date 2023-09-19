// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../contracts/liblock.sol";
import "./mGovernance.sol";
import "./proposal.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Operator is Ownable {
    Liblock private libToken;
    Governance private governanceContract;
    Proposal private proposalContract;

    constructor(
        address _libToken,
        address _governanceContract,
        address _proposalContract
    ) {
        require(_libToken != address(0), "Invalid LIB Token address");
        require(
            _governanceContract != address(0),
            "Invalid Governance contract address"
        );
        require(
            _proposalContract != address(0),
            "Invalid Proposal contract address"
        );

        libToken = Liblock(_libToken);
        governanceContract = Governance(_governanceContract);
        proposalContract = Proposal(_proposalContract);

        // Perform any additional initialization if needed.
    }

    /**
     * @dev Get the user's balance of LIB tokens.
     * @param user The user's Ethereum wallet address.
     * @return The balance of LIB tokens held by the user.
     */
    function getUserBalance(address user) external view returns (uint256) {
        return libToken.balanceOf(user);
    }

    /**
     * @dev Get the voting power of a given user based on their LIB token holdings.
     * Voting power is equivalent to the number of LIB tokens held by the user.
     * @param _account The user's ETH wallet
     * @return votes The voting power of the specified user.
     */
    function getRemVotes(address _account)
        public
        view
        returns (uint256 votes)
    {
        // Use staticcall instead of call to prevent state changes in the called contract
        (bool success, bytes memory result) = address(libToken).staticcall(
            abi.encodeWithSignature("getVotes(address)", _account)
        );

        if (success && result.length >= 32) {
            // Extract the votes from the returned bytes data
            assembly {
                votes := mload(add(result, 32))
            }
        } else {
            revert("Failed to retrieve votes");
        }
    }

    /**
     * @dev Get the number of times a user has voted on proposals.
     * @param _account The user's Ethereum wallet address.
     * @return votes The number of votes made by the specified user.
     */
    function getNumVotes(address _account)
        public
        view
        returns (uint256 votes)
    {
        // Use staticcall instead of call to prevent state changes in the called contract
        (bool success, bytes memory result) = address(libToken).staticcall(
            abi.encodeWithSignature("getPastVotes(address)", _account)
        );

        if (success && result.length >= 32) {
            // Extract the votes from the returned bytes data
            assembly {
                votes := mload(add(result, 32))
            }
        } else {
            revert("Failed to retrieve votes history");
        }
    }

    // Additional functions for ownership management and upgradability

    /**
     * @dev Allows the current owner to transfer ownership to a new address.
     * Only callable by the contract owner.
     * 
     * Requirements:
     *
      - `newOwner` cannot be the zero address.   
      - Only callable by the contract owner. 
      
      Emits an {OwnershipTransferred} event indicating that ownership has been transferred to `newOwner`.
     
       */

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        super.transferOwnership(newOwner);
    }
}