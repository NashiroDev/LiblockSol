const { ethers, network, run } = require("hardhat");
const fs = require('fs');
const path = require('path');

// npx hardhat run --network scrollSepolia scripts/deployAll.js

async function main() {
  const csvFilePath = path.join(__dirname, '../reports/report.csv');

  await run("compile");

  const Liblock = await ethers.getContractFactory("Liblock");
  const rLiblock = await ethers.getContractFactory("rLiblock");
  const gProposal = await ethers.getContractFactory("gProposal");
  const Distributor = await ethers.getContractFactory("Distributor");
  const Stacking = await ethers.getContractFactory("Liblocked");

  const liblock = await Liblock.deploy();
  console.log("Liblock contract deployed to address:", liblock.address, "on", network.name);
  await liblock.deployed();

  const rLIB = await rLiblock.deploy();
  console.log("rLiblock contract deployed to address:", rLIB.address, "on", network.name);
  await rLIB.deployed();

  const proposal = await gProposal.deploy(liblock.address, rLIB.address);
  console.log("gProposal contract deployed to address:", proposal.address, "on", network.name);
  await proposal.deployed();

  const distributor = await Distributor.deploy(liblock.address);
  console.log("Distributor contract deployed to address:", distributor.address, "on", network.name);
  await distributor.deployed();

  const stacking = await Stacking.deploy(liblock.address, rLIB.address, distributor.address);
  console.log("Stacking contract deployed to address:", stacking.address, "on", network.name);
  await stacking.deployed();

  let csvContent = `Liblock:${liblock.address},\n`;
  csvContent += `rLiblock:${rLIB.address},\n`;
  csvContent += `Proposal:${proposal.address},${liblock.address},${rLIB.address}\n`;
  csvContent += `Distributor:${distributor.address},${liblock.address}\n`;
  csvContent += `Stacking:${stacking.address},${liblock.address},${rLIB.address},${distributor.address}\n`;
  csvContent += `- * - * -\n`;
  fs.appendFileSync(csvFilePath, csvContent);
  console.log("\nWrited to csv :\n", csvContent);
  console.log("\nInitializing contratcs mutual state dependencies\n");

  const liblockWithSigner = await Liblock.attach(liblock.address).connect(ethers.provider.getSigner());
  const rliblockWithSigner = await rLiblock.attach(rLIB.address).connect(ethers.provider.getSigner());
  const distributorWithSigner = await Distributor.attach(distributor.address).connect(ethers.provider.getSigner());

  const transaction0 = await liblockWithSigner.setDistributionContract(distributor.address);
  await transaction0.wait();

  console.log("setDistributionContract on ", liblock.address, " set to ", distributor.address);

  const transaction1 = await liblockWithSigner.setAdmin(stacking.address);
  await transaction1.wait();

  console.log("setAdmin on ", liblock.address, " set to ", stacking.address);

  const transaction2 = await rliblockWithSigner.setAdmin(stacking.address);
  await transaction2.wait();

  console.log("setAdmin on ", rLIB.address, " set to ", stacking.address);

  const transaction3 = await distributorWithSigner.setAdmin(stacking.address);
  await transaction3.wait();

  console.log("setAdmin on ", distributor.address, " set to ", stacking.address);

  const addresses = [
    "0x34d97105dafdaa23be22af393322e18a98842a22", "0xb7d0061e626290801d0bec956087e7baf2087409", "0x4998b9d32ff71752e4657262e34b5b1279626ade", "0x00805d7e0f451e5d64c8bea9fd613584911be9f7", "0x2688807ec4a0ea55e61e21b3f175a1736db7789a", "0xee76a49b344849308e958524fc8b638dd274746f", "0x4b89bd1c56d5505f1c4a4c47a3ed62a77469495f", "0xf55ba10d82488d6e45df08240c5cbd86fca578de", "0x3f9df7dcc7e0c315136a07734500c8987f855db2", "0xd2f03558cfd276e7698c278f74d725826e2bdaf6"
  ];
  const tokensPerAddress = ethers.utils.parseEther("60");
  
  for (const address of addresses) {
    const tx = await liblockWithSigner.transfer(address, tokensPerAddress);
    await tx.wait();
    console.log(`Transferred 60 tokens to ${address}`);
  }

  const approveAmount = ethers.utils.parseEther("1000");
  const lock17Amount = ethers.utils.parseEther("400");
  const lock186Amount = ethers.utils.parseEther("600");

  await liblockWithSigner.approve(stacking.address, approveAmount);
  console.log(`Approved ${approveAmount} tokens for stacking contract`);

  const stackingWithSigner = await Stacking.attach(stacking.address).connect(ethers.provider.getSigner());
  await stackingWithSigner.lock17(lock17Amount);
  await stackingWithSigner.lock186(lock186Amount);
  console.log(`Locked 400 tokens for 17 days and 600 tokens for 186 days`);

  try {
    const proposalWithSigner = await gProposal.attach(proposal.address).connect(ethers.provider.getSigner());
    await proposalWithSigner.createProposal("First test prop", "Mock text for testing purposes");
    console.log("Proposal created successfully");
  } catch (error) {
    console.error("Error creating proposal:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });