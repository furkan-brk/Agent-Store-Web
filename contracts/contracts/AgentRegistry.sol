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
    mapping(address => bool) private _registrars;
    uint256 public totalAgents;
    bool public openRegistration; // when true, any address can register

    event AgentRegistered(
        uint256 indexed agentId,
        address indexed creator,
        bytes32 contentHash,
        bytes32 imageHash
    );
    event AgentDeactivated(uint256 indexed agentId);
    event RegistrarAdded(address indexed registrar);
    event RegistrarRemoved(address indexed registrar);

    error AlreadyRegistered();
    error AgentNotFound();
    error NotAuthorized();
    error AlreadyInactive();
    error ZeroHash();

    constructor() Ownable(msg.sender) {
        _registrars[msg.sender] = true;
        openRegistration = true; // default open for testnet; set to false for production
    }

    /// @notice Only registrars or owner can call when openRegistration is false.
    modifier onlyRegistrar() {
        if (!openRegistration && !_registrars[msg.sender] && msg.sender != owner()) revert NotAuthorized();
        _;
    }

    /// @notice Add a registrar address (owner only).
    function addRegistrar(address r) external onlyOwner {
        _registrars[r] = true;
        emit RegistrarAdded(r);
    }

    /// @notice Remove a registrar address (owner only).
    function removeRegistrar(address r) external onlyOwner {
        _registrars[r] = false;
        emit RegistrarRemoved(r);
    }

    /// @notice Toggle open registration (owner only).
    function setOpenRegistration(bool open) external onlyOwner {
        openRegistration = open;
    }

    /// @notice Check if an address is a registrar.
    function isRegistrar(address addr) external view returns (bool) {
        return _registrars[addr];
    }

    /**
     * @notice Register a new agent with its prompt hash and AI avatar image hash.
     * @param agentId     Backend database ID of the agent.
     * @param contentHash keccak256 of the agent's system prompt (prevents prompt tampering).
     * @param imageHash   keccak256 of the raw avatar image bytes from GenerateAvatarImage.
     *                    Pass bytes32(0) if the image generation failed.
     */
    function registerAgent(uint256 agentId, bytes32 contentHash, bytes32 imageHash) external onlyRegistrar {
        if (contentHash == bytes32(0)) revert ZeroHash();
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
