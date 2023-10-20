async function main() {
    const Stacking = await ethers.getContractFactory("Liblocked");
  
    // Start deployment, returning a promise that resolves to a contract object
    const stacking = await Stacking.deploy('LIB', 'rLIB', 'Distributor');
    console.log("Contract deployed to address:", stacking.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });