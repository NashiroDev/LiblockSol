async function main() {
    const Distributor = await ethers.getContractFactory("Distributor");
  
    // Start deployment, returning a promise that resolves to a contract object
    const distributor = await Distributor.deploy('LIB');
    console.log("Contract deployed to address:", distributor.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });