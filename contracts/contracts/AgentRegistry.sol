// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  AgentRegistry
 * @notice Records agent ownership, prompt hashes, and AI-generated avatar image hashes
 *         on-chain for provenance. Every agent registered here has its content and
 *         generated image anchored immutably to the Monad testnet.
 *
 * imageHash is keccak256 of the raw avatar image bytes produced by GenerateAvatarImage
 * (Gemini Imagen 3). This allows anyone to verify that an avatar has not been tampered
 * with after registration.
 */
contract AgentRegistry is Ownable {
    struct AgentRecord {
        address creator;
        bytes32 contentHash;  // keccak256 of agent prompt
        bytes32 imageHash;    // keccak256 of AI-generated avatar image bytes (from GenerateAvatarImage)
        uint256 registeredAt;
        bool    active;
    }

    mapping(uint256 => AgentRecord) public agents;
    mapping(address => uint256[])   public creatorAgents;
    uint256 public totalAgents;

    event AgentRegistered(
        uint256 indexed agentId,
        address indexed creator,
        bytes32 contentHash,
        bytes32 imageHash
    );
    event AgentDeactivated(uint256 indexed agentId);

    error AlreadyRegistered();
    error AgentNotFound();
    error NotAuthorized();
    error AlreadyInactive();

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Register a new agent with its prompt hash and AI avatar image hash.
     * @param agentId     Backend database ID of the agent.
     * @param contentHash keccak256 of the agent's system prompt (prevents prompt tampering).
     * @param imageHash   keccak256 of the raw avatar image bytes from GenerateAvatarImage.
     *                    Pass bytes32(0) if the image generation failed.
     */
    function registerAgent(uint256 agentId, bytes32 contentHash, bytes32 imageHash) external {
        if (agents[agentId].registeredAt != 0) revert AlreadyRegistered();
        agents[agentId] = AgentRecord({
            creator:      msg.sender,
            contentHash:  contentHash,
            imageHash:    imageHash,
            registeredAt: block.timestamp,
            active:       true
        });
        creatorAgents[msg.sender].push(agentId);
        totalAgents++;
        emit AgentRegistered(agentId, msg.sender, contentHash, imageHash);
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

    /**
     * @notice Verify that an agent's prompt has not been tampered with.
     */
    function verify(uint256 agentId, bytes32 contentHash) external view returns (bool) {
        AgentRecord memory r = agents[agentId];
        return r.active && r.contentHash == contentHash;
    }

    /**
     * @notice Verify that an agent's AI-generated avatar has not been tampered with.
     * @param agentId   The agent to check.
     * @param imageHash keccak256 of the image bytes to verify against the on-chain record.
     */
    function verifyImage(uint256 agentId, bytes32 imageHash) external view returns (bool) {
        AgentRecord memory r = agents[agentId];
        return r.active && r.imageHash != bytes32(0) && r.imageHash == imageHash;
    }

    /**
     * @notice Verify both prompt and avatar image integrity in a single call.
     */
    function verifyFull(
        uint256 agentId,
        bytes32 contentHash,
        bytes32 imageHash
    ) external view returns (bool) {
        AgentRecord memory r = agents[agentId];
        return r.active && r.contentHash == contentHash && r.imageHash == imageHash;
    }
}
