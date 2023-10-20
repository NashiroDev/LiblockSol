const fs = require('fs');
const path = require('path');

async function main() {
    const csvFilePath = path.join(__dirname, '../reports/report.csv');

    const Liblock = await ethers.getContractFactory("Liblock");
    const rLiblock = await ethers.getContractFactory("rLiblock");
    const gProposal = await ethers.getContractFactory("gProposal");
    const Distributor = await ethers.getContractFactory("Distributor");
    const Stacking = await ethers.getContractFactory("Liblocked");

    const liblock = await Liblock.deploy();   
    console.log("Contract deployed to address:", liblock.address);

    const rLIB = await rLiblock.deploy();
    console.log("Contract deployed to address:", rLIB.address);

    const proposal = await gProposal.deploy(liblock.address);
    console.log("Contract deployed to address:", proposal.address);

    const distributor = await Distributor.deploy(liblock.address);
    console.log("Contract deployed to address:", distributor.address);

    const stacking = await Stacking.deploy(liblock.address, rLIB.address, distributor.address);
    console.log("Contract deployed to address:", stacking.address);

    const csvContent = `Liblock Address,${liblock.address}\nrLiblock Address,${rLIB.address}\nProposal Address,${proposal.address}\nDistributor Address,${distributor.address}\nStacking Address,${stacking.address}\n- * - * -\n`;
    fs.appendFileSync(csvFilePath, csvContent);
  }
  

  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });