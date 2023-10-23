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
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

  