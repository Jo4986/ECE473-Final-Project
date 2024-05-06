// SPDX-License-Identifier: MIT

// This code sets up a governance system, with a defined set and flow of the proposal and voting proceess in alignment to the rules, 
// processes, and mechanisms by which decisions are made within our DAO (captchaDAO). 
pragma solidity ^0.8.0;

import "./DAOToken.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Governance {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    DAOToken public daoToken;
    // Define key elements to the Proposal structure —specific to each proposal
    struct Proposal {
        uint256 id;
        address proposer;
        string  description;
        uint256 totalAmount;
        address payable recipient;
        uint256 startTime;
        uint256 endTime;
        uint256 VotesFor;
        uint256 VotesAgainst;
        mapping(address => uint256) votes;
        EnumerableSet.AddressSet voters;
        bool executed;
    }

    // Create an array of proposals containing the elements above. 
    // *This is accessible via a helper function below*
    Proposal[] proposals;

    // Linearly listed events inputting voter and proposer information
    event NewProposal(uint256 indexed proposalId, address indexed proposer, string description, uint256 totalAmount);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed proposer, bool successful, uint256 VotesFor, uint256 VotesAgainst);

    uint256 constant VOTING_PERIOD = 3 days;

    constructor(DAOToken _daoToken) {
        daoToken = _daoToken;
    }
    // create a proposal with the information of the prososal and the timelines of the proposal process
    function createProposal(string memory description, uint256 totalAmount, address payable recipient) public {
        uint256 proposalId = proposals.length;
        Proposal storage proposal = proposals.push();
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.amount = totalAmount;
        proposal.recipient = recipient;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        emit NewProposal(proposalId, msg.sender, description, totalAmount);
    }

    // voting function
    function vote(uint256 proposalId, uint256 totalAmount, bool support) public {
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period has ended");
        require(daoToken.balanceOf(msg.sender) >= totalAmount, "Not enough tokens");
        require(proposals[proposalId].votes[msg.sender] == 0, "Already voted");

        daoToken.lockToken(msg.sender, totalAmount);

        uint256 voteWeight = sqrt(totalAmount);
        proposals[proposalId].votes[msg.sender] = voteWeight;

        if (support) {
            proposals[proposalId].VotesFor += voteWeight;
        } else {
            proposals[proposalId].VotesAgainst += voteWeight;
        }

        emit VoteCasted(proposalId, msg.sender, support, voteWeight);
    }

    // proposal execution function
    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp > proposal.endTime, "Voting period not yet ended");

        proposal.executed = true;
        bool successful = proposal.VotesFor > proposal.VotesAgainst;
        emit ProposalExecuted(proposalId, proposal.proposer, successful, proposal.VotesFor, proposal.VotesAgainst);

        if (successful && proposal.recipient != address(0)) {
            proposal.recipient.transfer(proposal.totalAmount);
        }
    }

    // Custom getter for proposals
    function getProposal(uint256 proposalId) public view returns (uint256, address, string memory, uint256, address payable, uint256, uint256, uint256, uint256, bool) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.id, proposal.proposer, proposal.description, proposal.totalAmount, proposal.recipient, proposal.startTime, proposal.endTime, proposal.VotesFor, proposal.VotesAgainst, proposal.executed);
    }

    // Custom getter for votes
    function getVotes(uint256 proposalId, address voter) external view returns (uint256) {
        return proposals[proposalId].votes[voter];
    }

    // Calculates the square root of a given unsigned integer 
    // Babylonian method to approximate the square root of the input integer y. 
    // It recursively refines the approximation until it converges to a certain precision 
    // To calculate vote weights based on token amounts.
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

