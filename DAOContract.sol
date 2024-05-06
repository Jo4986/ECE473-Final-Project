// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the required contracts
import "./DAOToken.sol";
import "./Governance.sol";
import "./Administrative.sol";

// DAOContract smart contract
contract DAOContract {
    // Instance variables for DAO components
    DAOToken public daoToken;
    Governance public governance;
    Administrative public administrative;

    // Constructor to initialize the DAOContract
    constructor(string memory tokenName, string memory tokenSymbol, uint256 initialSupply) {
        // Deploying the DAOToken contract with the specified parameters
        daoToken = new DAOToken(tokenName, tokenSymbol, initialSupply);
        
        // Deploying the Governance contract and passing the DAOToken instance as an argument
        governance = new Governance(daoToken);
        
        // Deploying the Administrative contract and passing the DAOToken instance as an argument
        administrative = new Administrative(daoToken);
    }
}
