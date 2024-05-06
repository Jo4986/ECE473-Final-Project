// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DAOToken.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Governance {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    DAOToken public daoToken;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 amount;
        address payable recipient;
        uint256 startTime;
        uint256 endTime;
        uint256 totalVotesFor;
        uint256 totalVotesAgainst;
        mapping(address => uint256) votes;
        EnumerableSet.AddressSet voters;
        bool executed;
    }

    // proposals should be public - FIX THIS
    Proposal[] proposals;

    event NewProposal(uint256 indexed proposalId, address indexed proposer, string description, uint256 amount);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed proposer, bool successful, uint256 totalVotesFor, uint256 totalVotesAgainst);

    uint256 constant VOTING_PERIOD = 3 days;

    constructor(DAOToken _daoToken) {
        daoToken = _daoToken;
    }

    function createProposal(string memory description, uint256 amount, address payable recipient) public {
        uint256 proposalId = proposals.length;
        Proposal storage proposal = proposals.push();
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.amount = amount;
        proposal.recipient = recipient;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        emit NewProposal(proposalId, msg.sender, description, amount);
    }

    function vote(uint256 proposalId, uint256 amount, bool support) public {
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period has ended");
        require(daoToken.balanceOf(msg.sender) >= amount, "Not enough tokens");
        require(proposals[proposalId].votes[msg.sender] == 0, "Already voted");

        daoToken.lockToken(msg.sender, amount);

        uint256 voteWeight = sqrt(amount);
        proposals[proposalId].votes[msg.sender] = voteWeight;

        if (support) {
            proposals[proposalId].totalVotesFor += voteWeight;
        } else {
            proposals[proposalId].totalVotesAgainst += voteWeight;
        }

        emit VoteCasted(proposalId, msg.sender, support, voteWeight);
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp > proposal.endTime, "Voting period not yet ended");

        proposal.executed = true;
        bool successful = proposal.totalVotesFor > proposal.totalVotesAgainst;
        emit ProposalExecuted(proposalId, proposal.proposer, successful, proposal.totalVotesFor, proposal.totalVotesAgainst);

        if (successful && proposal.recipient != address(0)) {
            proposal.recipient.transfer(proposal.amount);
        }
    }

    // Custom getter for proposals
    function getProposal(uint256 proposalId) public view returns (uint256, address, string memory, uint256, address payable, uint256, uint256, uint256, uint256, bool) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.id, proposal.proposer, proposal.description, proposal.amount, proposal.recipient, proposal.startTime, proposal.endTime, proposal.totalVotesFor, proposal.totalVotesAgainst, proposal.executed);
    }

    // Custom getter for votes
    function getVotes(uint256 proposalId, address voter) external view returns (uint256) {
        return proposals[proposalId].votes[voter];
    }

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
