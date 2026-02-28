const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("\n=== Agent Store — Contract Deployment ===\n");
  const [deployer] = await ethers.getSigners();
  console.log("Deployer :", deployer.address);
  const bal = await ethers.provider.getBalance(deployer.address);
  console.log("Balance  :", ethers.formatEther(bal), "MON\n");

  // ── AgentStoreCredits ────────────────────────────────────────────────────
  console.log("Deploying AgentStoreCredits...");
  const Credits = await ethers.getContractFactory("AgentStoreCredits");
  const credits = await Credits.deploy();
  await credits.waitForDeployment();
  const creditsAddr = await credits.getAddress();
  console.log("  ✓ AgentStoreCredits:", creditsAddr);

  // ── AgentRegistry ────────────────────────────────────────────────────────
  console.log("Deploying AgentRegistry...");
  const Registry = await ethers.getContractFactory("AgentRegistry");
  const registry = await Registry.deploy();
  await registry.waitForDeployment();
  const registryAddr = await registry.getAddress();
  console.log("  ✓ AgentRegistry    :", registryAddr);

  // ── Save deployment ──────────────────────────────────────────────────────
  const out = {
    network: "monad_testnet",
    chainId: 10143,
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
    contracts: {
      AgentStoreCredits: creditsAddr,
      AgentRegistry:     registryAddr,
    },
  };
  fs.writeFileSync(path.join(__dirname, "../deployments.json"), JSON.stringify(out, null, 2));
  console.log("\nSaved to deployments.json");

  console.log("\n--- Add to backend .env ---");
  console.log(`CREDITS_CONTRACT_ADDRESS=${creditsAddr}`);
  console.log(`REGISTRY_CONTRACT_ADDRESS=${registryAddr}`);
  console.log("---------------------------\n");
}

main().catch((e) => { console.error(e); process.exit(1); });
