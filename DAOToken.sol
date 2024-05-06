// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DAOToken is ERC20, AccessControl {
    using SafeMath for uint256;

    // Define a new role identifier for the CCUS company
    bytes32 public constant CCUS_ROLE = keccak256("CCUS_ROLE");
    mapping(address => uint256) private _lockedTokens;

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function lockToken(address account, uint256 amount) public onlyRole(CCUS_ROLE) {
        require(amount <= balanceOf(account), "DAOToken: cannot lock more than the balance");
        _lockedTokens[account] = _lockedTokens[account].add(amount);
        _transfer(account, address(this), amount);
    }

    function unlockToken(address account, uint256 amount) public onlyRole(CCUS_ROLE) {
        uint256 lockedBalance = _lockedTokens[account];
        require(amount <= lockedBalance, "DAOToken: cannot unlock more tokens than are locked");
        _lockedTokens[account] = _lockedTokens[account].sub(amount);
        _transfer(address(this), account, amount);
    }

    function getLockedTokens(address account) public view returns (uint256) {
        return _lockedTokens[account];
    }

    function grantCCUSRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CCUS_ROLE, account);
    }
}
