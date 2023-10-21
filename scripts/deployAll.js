import { ethers, network, run } from "hardhat";
import fs from 'fs';
import path from 'path';

async function main() {
  const csvFilePath = path.join(__dirname, '../reports/report.csv');

  const Liblock = await ethers.getContractFactory("Liblock");
  const rLiblock = await ethers.getContractFactory("rLiblock");
  const gProposal = await ethers.getContractFactory("gProposal");
  const Distributor = await ethers.getContractFactory("Distributor");
  const Stacking = await ethers.getContractFactory("Liblocked");

  const liblock = await Liblock.deploy();
  console.log("Liblock contract deployed to address:", liblock.address, "on", network.name);
  await liblock.deployed();
  await verifyContract(liblock.address);

  const rLIB = await rLiblock.deploy();
  console.log("rLiblock contract deployed to address:", rLIB.address, "on", network.name);
  await rLIB.deployed();
  await verifyContract(rLIB.address);

  const proposal = await gProposal.deploy(liblock.address);
  console.log("gProposal contract deployed to address:", proposal.address, "on", network.name);
  await proposal.deployed();
  await verifyContract(proposal.address, [liblock.address, rLIB.address]);

  const distributor = await Distributor.deploy(liblock.address);
  console.log("Distributor contract deployed to address:", distributor.address, "on", network.name);
  await distributor.deployed();
  await verifyContract(distributor.address, [liblock.address]);

  const stacking = await Stacking.deploy(liblock.address, rLIB.address, distributor.address);
  console.log("Stacking contract deployed to address:", stacking.address, "on", network.name);
  await stacking.deployed();
  await verifyContract(stacking.address, [liblock.address, rLIB.address, distributor.address]);

  const csvContent = `Liblock Address,${liblock.address}\nrLiblock Address,${rLIB.address}\nProposal Address,${proposal.address}\nDistributor Address,${distributor.address}\nStacking Address,${stacking.address}\n- * - * -\n`;
  fs.appendFileSync(csvFilePath, csvContent);

  const liblockWithSigner = await Liblock.attach(liblock.address).connect(ethers.provider.getSigner());
  const rliblockWithSigner = await rLiblock.attach(rLIB.address).connect(ethers.provider.getSigner());
  const distributorWithSigner = await Distributor.attach(distributor.address).connect(ethers.provider.getSigner());

  const transaction0 = await liblockWithSigner.setDistributionContract(stacking.address);
  await transaction0.wait();

  console.log("setDistributionContract set!");

  const transaction1 = await liblockWithSigner.setAdmin(stacking.address);
  await transaction1.wait();

  console.log("admin set for Liblock!");

  const transaction2 = await rliblockWithSigner.setAdmin(stacking.address);
  await transaction2.wait();

  console.log("admin set for rLiblock!");

  const transaction3 = await distributorWithSigner.setAdmin(stacking.address);
  await transaction3.wait();

  console.log("admin set for Distributor!");
}

async function verifyContract(contractAddress, args=[]) {
  console.log(`Verifying contract at address: ${contractAddress}`);
  await run(`verify:verify`, {
    address: contractAddress,
    constructorArguments: args,
  });
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });