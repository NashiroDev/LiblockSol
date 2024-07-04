const { ethers, network, run } = require("hardhat");
const fs = require('fs');
const path = require('path');

// npx hardhat run --network scrollSepolia test/liblocked.js

async function main() {
    const Liblock = await ethers.getContractFactory("Liblock");
    const Stacking = await ethers.getContractFactory("Liblocked");

    const LibAddress = "0xA5222Fc930c15C79177ea112571a667157d401f3";
    const stackAddress = "0x59959ecF62bE523eDbBd277b7ff6AB1834a0A168";

    const liblockWithSigner = await Liblock.attach(LibAddress).connect(ethers.provider.getSigner());
    const stackingWithSigner = await Stacking.attach(stackAddress).connect(ethers.provider.getSigner());

    const approveAmount = ethers.utils.parseEther("100000");
    const lock17Amount = ethers.utils.parseEther("400");
    const lock186Amount = ethers.utils.parseEther("6000");

    await liblockWithSigner.approve(stackAddress, approveAmount);
    console.log(`Approved ${approveAmount} tokens for stacking contract`);

    await stackingWithSigner.lock17(lock17Amount);
    await stackingWithSigner.lock186(lock186Amount);
    console.log(`Locked 400 tokens for 17 days and 6000 tokens for 186 days`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });