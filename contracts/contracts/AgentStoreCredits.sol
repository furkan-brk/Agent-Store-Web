// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title  AgentStoreCredits
 * @notice On-chain credit system for Agent Store on Monad testnet.
 *         Credits gate agent interactions and are granted on first registration.
 */
contract AgentStoreCredits is Ownable, ReentrancyGuard {

    // ── State ────────────────────────────────────────────────────────────────
    mapping(address => uint256) private _credits;
    mapping(address => bool)    private _minters;
    mapping(address => uint256) private _totalEarned;
    mapping(address => uint256) private _totalSpent;

    uint256 public constant INITIAL_GRANT      = 100;
    uint256 public constant MAX_CREDITS        = 10_000;
    uint256 public constant AGENT_USE_COST     = 5;
    uint256 public constant AGENT_CREATE_COST  = 10;

    // ── Events ───────────────────────────────────────────────────────────────
    event CreditsGranted(address indexed user, uint256 amount, string reason);
    event CreditsSpent  (address indexed user, uint256 amount, string reason);
    event MinterAdded   (address indexed minter);
    event MinterRemoved (address indexed minter);

    // ── Errors ───────────────────────────────────────────────────────────────
    error InsufficientCredits(uint256 have, uint256 need);
    error NotMinter();
    error ZeroAddress();
    error ZeroAmount();

    // ── Constructor ──────────────────────────────────────────────────────────
    constructor() Ownable(msg.sender) {
        _minters[msg.sender] = true;
    }

    modifier onlyMinter() {
        if (!_minters[msg.sender] && msg.sender != owner()) revert NotMinter();
        _;
    }

    // ── External ─────────────────────────────────────────────────────────────

    /// @notice Register a new user and grant initial credits (idempotent).
    function registerUser(address user) external onlyMinter {
        if (user == address(0)) revert ZeroAddress();
        if (_totalEarned[user] == 0) {
            _grant(user, INITIAL_GRANT, "Welcome bonus");
        }
    }

    /// @notice Grant arbitrary credits (minter only).
    function grantCredits(address user, uint256 amount, string calldata reason) external onlyMinter {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _grant(user, amount, reason);
    }

    /// @notice Spend AGENT_USE_COST credits.
    function spendForAgentUse(address user) external onlyMinter nonReentrant {
        _spend(user, AGENT_USE_COST, "Agent use");
    }

    /// @notice Spend AGENT_CREATE_COST credits.
    function spendForAgentCreate(address user) external onlyMinter nonReentrant {
        _spend(user, AGENT_CREATE_COST, "Agent create");
    }

    /// @notice Spend arbitrary credits.
    function spendCredits(address user, uint256 amount, string calldata reason)
        external onlyMinter nonReentrant {
        _spend(user, amount, reason);
    }

    // ── View ─────────────────────────────────────────────────────────────────

    function balanceOf(address user) external view returns (uint256) {
        return _credits[user];
    }

    function getStats(address user)
        external view
        returns (uint256 balance, uint256 totalEarned, uint256 totalSpent)
    {
        return (_credits[user], _totalEarned[user], _totalSpent[user]);
    }

    function hasEnough(address user, uint256 amount) external view returns (bool) {
        return _credits[user] >= amount;
    }

    function isMinter(address addr) external view returns (bool) {
        return _minters[addr];
    }

    // ── Admin ─────────────────────────────────────────────────────────────────
    function addMinter(address m) external onlyOwner {
        if (m == address(0)) revert ZeroAddress();
        _minters[m] = true;
        emit MinterAdded(m);
    }

    function removeMinter(address m) external onlyOwner {
        _minters[m] = false;
        emit MinterRemoved(m);
    }

    // ── Internal ─────────────────────────────────────────────────────────────
    function _grant(address user, uint256 amount, string memory reason) internal {
        uint256 space = MAX_CREDITS - _credits[user];
        if (amount > space) amount = space;
        if (amount == 0) return;
        _credits[user]      += amount;
        _totalEarned[user]  += amount;
        emit CreditsGranted(user, amount, reason);
    }

    function _spend(address user, uint256 amount, string memory reason) internal {
        uint256 bal = _credits[user];
        if (bal < amount) revert InsufficientCredits(bal, amount);
        _credits[user]     -= amount;
        _totalSpent[user]  += amount;
        emit CreditsSpent(user, amount, reason);
    }
}
