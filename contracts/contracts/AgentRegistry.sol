// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  AgentRegistry
 * @notice Records agent ownership and content hashes on-chain for provenance.
 */
contract AgentRegistry is Ownable {
    struct AgentRecord {
        address creator;
        bytes32 contentHash;  // keccak256 of agent prompt
        uint256 registeredAt;
        bool    active;
    }

    mapping(uint256 => AgentRecord) public agents;
    mapping(address => uint256[])   public creatorAgents;
    uint256 public totalAgents;

    event AgentRegistered (uint256 indexed agentId, address indexed creator, bytes32 contentHash);
    event AgentDeactivated(uint256 indexed agentId);

    error AlreadyRegistered();
    error AgentNotFound();
    error NotAuthorized();
    error AlreadyInactive();

    constructor() Ownable(msg.sender) {}

    function registerAgent(uint256 agentId, bytes32 contentHash) external {
        if (agents[agentId].registeredAt != 0) revert AlreadyRegistered();
        agents[agentId] = AgentRecord({
            creator:      msg.sender,
            contentHash:  contentHash,
            registeredAt: block.timestamp,
            active:       true
        });
        creatorAgents[msg.sender].push(agentId);
        totalAgents++;
        emit AgentRegistered(agentId, msg.sender, contentHash);
    }

    function deactivateAgent(uint256 agentId) external {
        AgentRecord storage r = agents[agentId];
        if (r.registeredAt == 0)                          revert AgentNotFound();
        if (r.creator != msg.sender && msg.sender != owner()) revert NotAuthorized();
        if (!r.active)                                     revert AlreadyInactive();
        r.active = false;
        emit AgentDeactivated(agentId);
    }

    function getAgent(uint256 agentId) external view returns (AgentRecord memory) {
        return agents[agentId];
    }

    function getCreatorAgents(address creator) external view returns (uint256[] memory) {
        return creatorAgents[creator];
    }

    function verify(uint256 agentId, bytes32 contentHash) external view returns (bool) {
        AgentRecord memory r = agents[agentId];
        return r.active && r.contentHash == contentHash;
    }
}
