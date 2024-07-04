const { ethers, network, run } = require("hardhat");
const fs = require('fs');
const path = require('path');

// npx hardhat run --network scrollSepolia test/governance.js

async function main() {
    const gProposal = await ethers.getContractFactory("gProposal");
    const rLiblock = await ethers.getContractFactory("rLiblock");

    const proposalAddress = "0xe297F738B0c6B7ca9Ef60d506822Ae55aaF30286";
    const rLiblockAddress = "0x081479b6528f438f466FFd93dAbA9cC317c97169";

    const proposalWithSigner = await gProposal.attach(proposalAddress).connect(ethers.provider.getSigner());
    const rLib = await rLiblock.attach(rLiblockAddress)

    const balancingCount = await proposalWithSigner.balancingCount();
    const epochFloor = await proposalWithSigner.balancing(balancingCount);
    console.log("Epoch floor:", epochFloor.toString());

    const signer = await ethers.provider.getSigner();
    const address = await signer.getAddress();
    const virtualPowerUsed = await proposalWithSigner.virtualPowerUsed(address, balancingCount);
    console.log("Virtual power used:", virtualPowerUsed.toString());

    const balance = await rLib.getVotes(await ethers.provider.getSigner().getAddress());
    console.log("Delegated balance:", balance.toString());

    const tx = await proposalWithSigner.createProposal("First test prop", "Mock text for testing purposes", { gasLimit: 500000 });
    await tx.wait();
    console.log("Proposal created successfully");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });