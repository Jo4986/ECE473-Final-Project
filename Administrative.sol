// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DAOToken.sol";

contract Administrative {
    mapping(address => address) public delegates;
    mapping(uint256 => uint256) public proposalTimelocks;

    event DelegationUpdated(address indexed delegator, address indexed delegatee);
    event TimelockSet(uint256 indexed proposalId, uint256 time);

    modifier onlyDAO() {
        require(msg.sender == address(daoToken), "Only DAO token contract can call this function");
        _;
    }

    DAOToken public daoToken;

    constructor(DAOToken _daoToken) {
        daoToken = _daoToken;
    }

    function delegate(address delegatee) public {
        delegates[msg.sender] = delegatee;
        emit DelegationUpdated(msg.sender, delegatee);
    }

    function undelegate() public {
        delete delegates[msg.sender];
        emit DelegationUpdated(msg.sender, address(0));
    }

    function setTimelock(uint256 proposalId, uint256 delay) public {
        proposalTimelocks[proposalId] = block.timestamp + delay;
        emit TimelockSet(proposalId, proposalTimelocks[proposalId]);
    }

    function lockToken(address account, uint256 amount) external onlyDAO {
        // Forward token locking functionality to DAO contract
        daoToken.lockToken(account, amount);
    }

    function unlockToken(address account, uint256 amount) external onlyDAO {
        // Forward token unlocking functionality to DAO contract
        daoToken.unlockToken(account, amount);
    }

    function getLockedTokens(address account) external view returns (uint256) {
        // Return locked tokens via DAO contract
        return daoToken.getLockedTokens(account);
    }

    function grantCCUSRole(address account) external onlyDAO {
        // Grant CCUS role via DAO contract
        daoToken.grantCCUSRole(account);
    }
}
