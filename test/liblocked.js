const { ethers, network, run } = require("hardhat");
const fs = require('fs');
const path = require('path');

// npx hardhat run --network scrollSepolia test/liblocked.js

async function main() {
    const Liblock = await ethers.getContractFactory("Liblock");
    const Stacking = await ethers.getContractFactory("Liblocked");

    const LibAddress = "0x4fcF5be4Ef60810e0207100bDf70Ac319E3fDa14";
    const stackAddress = "0x1444bc27DD20906d99eAB4a8A765B9f03667BD46";

    const liblockWithSigner = await Liblock.attach(LibAddress).connect(ethers.provider.getSigner());
    const stackingWithSigner = await Stacking.attach(stackAddress).connect(ethers.provider.getSigner());

    const approveAmount = ethers.utils.parseEther("1000");
    const lock17Amount = ethers.utils.parseEther("400");
    const lock186Amount = ethers.utils.parseEther("600");

    await liblockWithSigner.approve(stackAddress, approveAmount);
    console.log(`Approved ${approveAmount} tokens for stacking contract`);

    await stackingWithSigner.lock17(lock17Amount);
    await stackingWithSigner.lock186(lock186Amount);
    console.log(`Locked 400 tokens for 17 days and 600 tokens for 186 days`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });